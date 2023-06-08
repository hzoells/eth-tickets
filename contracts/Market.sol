pragma solidity ^0.8.9;
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";

contract Market is ERC1155Holder {
  struct DealShare {
    address payable wallet;
    uint share;
    uint totalValue;
  }

  struct Deal {
    uint id;
    address contractAddress;
    uint tokenId;
    address payable owner;
    uint price;
    uint supply;
    uint sold;
    uint totalValue;
    bool isActive;
  }

  uint private dealIndex = 1;

  mapping (uint => DealShare[]) private shares;

  mapping (uint => Deal) private deals;

  mapping (address => mapping(uint => uint[])) private contractTokenToDealIds;

  mapping (address => uint[]) private ownerToDealIds;

  event DealCreated(address indexed creator, uint indexed dealId);

  event PurchaseCompleted (address indexed buyer, uint indexed dealId, uint amount);

  // Deal Index
  function getDealIndex() public view returns(uint) {
    return dealIndex;
  }

  function _incrementDealIndex() internal {
    dealIndex = dealIndex + 1;
  }

  // Deals
  function getDeal(uint _dealId) external view returns(Deal memory) {
    return _getDeal(_dealId);
  }

  function _getDeal(uint _dealId) internal view returns (Deal memory) {
    return deals[_dealId];
  }

  function _addDeal(Deal memory deal) internal {
    deals[deal.id] = deal;
  }

  function _removeDeal(uint dealId) internal {
    delete deals[dealId];
  }

  // Shares
  function getShares(uint _dealId) external view returns(DealShare[] memory) {
    return _getShares(_dealId);
  }

  function _getShares(uint _dealId) internal view returns (DealShare[] memory) {
    return shares[_dealId];
  }

  function _addShare(DealShare memory share, uint dealId) internal {
    shares[dealId].push(share);
  }

  function _removeShares(uint dealId) internal {
    delete shares[dealId];
  }

  // Contract and Token to Deal Id
  function getContractTokenDealId(address _contract, uint _tokenId) external view returns(uint[] memory) {
    return _getContractTokenDealId(_contract, _tokenId);
  }

  function _getContractTokenDealId(address _contract, uint _tokenId) internal view returns(uint[] memory) {

    return contractTokenToDealIds[_contract][_tokenId];
  }

  function _addContractTokenDealId(address _contract, uint _tokenId, uint _dealId) internal {
    contractTokenToDealIds[_contract][_tokenId].push(_dealId);
  }

  function _removeContractTokenDealId(address _contract, uint _tokenId, uint _dealId) internal {
    _removeStorageArrayElement(contractTokenToDealIds[_contract][_tokenId], _dealId);
  }

  // Owner to Deals
  function getOwnerDealIds(address _ownerAddress) public view returns(uint[] memory) {
    return _getOwnerDealIds(_ownerAddress);
  }

  function _getOwnerDealIds(address _ownerAddress) internal view returns(uint[] memory) {
    return ownerToDealIds[_ownerAddress];
  }

  function _addOwnerDealId(address _ownerAddress, uint _dealId) internal {
    ownerToDealIds[_ownerAddress].push(_dealId);
  }

  function _removeOwnerDealId(address _ownerAddress, uint _dealId) internal {
    _removeStorageArrayElement(ownerToDealIds[_ownerAddress], _dealId);
  }

  // Common
  function _removeStorageArrayElement(uint[] storage _array, uint _value) internal {
    bool foundValue = false;
    uint valueIndex = 0;
    for (uint index = 0; index < _array.length && !foundValue; index++) {
      if (_array[index] == _value) {
        foundValue = true;
        valueIndex = index;
      }
    }

    if (foundValue) {
      _array[valueIndex] = _array[_array.length -1];
      _array.pop();
    }
  }


  // Controls

  function createDeal(
    address _contractAddress, 
    uint _tokenId, 
    uint _price, 
    uint _supply,
    address payable[] memory wallets,
    uint[] memory walletShares) public returns (uint) {
    ERC1155 supplyContract = ERC1155(_contractAddress);

    require(supplyContract.balanceOf(msg.sender, _tokenId) >= _supply, "ERC1155Market: Insufficient supply");
    require(supplyContract.isApprovedForAll(msg.sender, address(this)), "ERC1155Market: Operator not approved");
    require(wallets.length == walletShares.length, "ERC1155Market: Invalid shares");

    uint totalShares = 0;
    for (uint i = 0; i < walletShares.length; i++) {
      totalShares = totalShares + walletShares[i];
    }

    require(totalShares <= 10000, "ERC1155Market: Invalid total number of shares");

    supplyContract.safeTransferFrom(msg.sender, address(this), _tokenId, _supply, "");
    
    uint dealId = getDealIndex();
    _incrementDealIndex();

    _addDeal(Deal(dealId, _contractAddress, _tokenId, payable(msg.sender), _price, _supply, 0, 0, true));
    _addContractTokenDealId(_contractAddress, _tokenId, dealId);
    _addOwnerDealId(msg.sender, dealId);

    for (uint i = 0; i < walletShares.length; i++) {
      _addShare(DealShare(wallets[i], walletShares[i], 0), dealId);
    }

    emit DealCreated(msg.sender, dealId);
    return dealId;
  }

  function cancelDeal(uint _dealId) public {
    Deal memory deal = deals[_dealId];

    require(deal.owner == msg.sender, "ERC1155Market: caller is not deal owner");

    ERC1155 supplyContract = ERC1155(deal.contractAddress);
    supplyContract.safeTransferFrom(address(this), msg.sender, deal.tokenId, deal.supply, "");
    deal.supply = 0;

    deals[_dealId] = deal;
  }

  function purchaseTokens(uint _dealId, uint _amount) public payable {
    Deal memory deal = deals[_dealId];
    ERC1155 supplyContract = ERC1155(deal.contractAddress);

    require(deal.supply >= _amount, "ERC1155Market: deal supply is below demanded amount");
    require(supplyContract.balanceOf(address(this), deal.tokenId) >= _amount, "ERC1155Market: contract error - insufficient supply");
    require(deal.isActive, "ERC1155Market: deal is inactive");
  

    bool paid = true;    
    uint remainingValue = deal.price * _amount;
    
    for (uint i; i < shares[_dealId].length; i++) {
      DealShare memory dealShare = shares[_dealId][i];
      uint shareAmount = (deal.price * _amount * dealShare.share) / 10000;
      bool sharePaid = dealShare.wallet.send(shareAmount);
      paid = paid && sharePaid;
      remainingValue = remainingValue - shareAmount;
      dealShare.totalValue = dealShare.totalValue + shareAmount;

      shares[_dealId][i] = dealShare;
    }

    bool ownerPaid = deal.owner.send(remainingValue);

    require(paid && ownerPaid, "ERC1155Market: payment failed");


    supplyContract.safeTransferFrom(address(this), msg.sender, deal.tokenId, _amount, "");

    deal.supply = deal.supply - _amount;
    deal.sold = deal.sold + _amount;
    deal.totalValue = deal.totalValue + (deal.price * _amount);

    deals[_dealId] = deal;

    emit PurchaseCompleted(msg.sender, _dealId, _amount);
  }

  function increaseDealSupply(uint _dealId, uint _supplyIncrement) public {
    Deal memory deal = deals[_dealId];
    require(deal.owner == msg.sender, "ERC1155Market: caller is not deal owner");

    ERC1155 supplyContract = ERC1155(deal.contractAddress);
    require(supplyContract.balanceOf(msg.sender, deal.tokenId) >= _supplyIncrement, "ERC1155Market: contract error - insufficient supply");

    supplyContract.safeTransferFrom(msg.sender, address(this), deal.tokenId, _supplyIncrement, "");

    deal.supply = deal.supply + _supplyIncrement;

    deals[_dealId] = deal;
  }

  function decreaseDealSupply(uint _dealId, uint _supplyDecrement) public {
    Deal memory deal = deals[_dealId];
    require(deal.owner == msg.sender, "ERC1155Market: caller is not deal owner");
    require(deal.supply >= _supplyDecrement, "ERC1155Market decreaseDealSupply: decrement larget than remaining supply");
    ERC1155 supplyContract = ERC1155(deal.contractAddress);

    supplyContract.safeTransferFrom(address(this), msg.sender, deal.tokenId, _supplyDecrement, "");

    deal.supply = deal.supply - _supplyDecrement;

    deals[_dealId] = deal;
  }

  function updateDealPrice(uint _dealId, uint _price) public {
    Deal memory deal = deals[_dealId];
    require(deal.owner == msg.sender, "ERC1155Market: caller is not deal owner");

    deal.price = _price;

    deals[_dealId] = deal;
  }

  function updateDealActivation(uint _dealId, bool _isActive) public {
    Deal memory deal = deals[_dealId];
    require(deal.owner == msg.sender, "ERC1155Market: caller is not deal owner");

    deal.isActive = _isActive;

    deals[_dealId] = deal;
  }

  function removeShare(uint _dealId, address payable wallet) public {
    Deal memory deal = deals[_dealId];
    require(deal.owner == msg.sender, "ERC1155Market: caller is not deal owner");


    for(uint i = 0; i < shares[_dealId].length; i++) {
      if (shares[_dealId][i].wallet == wallet) {
        delete shares[_dealId][i];
      }
    }
  }

  function updateShare(uint _dealId, address payable wallet, uint newShare) public {
    Deal memory deal = deals[_dealId];
    require(deal.owner == msg.sender, "ERC1155Market: caller is not deal owner");

    uint ownerShareIndex = shares[_dealId].length;
    uint totalShares = newShare;
    for(uint i = 0; i < shares[_dealId].length; i++) {
      if (shares[_dealId][i].wallet == wallet) {
        ownerShareIndex = i;
      } else {
        totalShares = totalShares + shares[_dealId][i].share;
      }
    }

    require(ownerShareIndex < shares[_dealId].length, "ERC1155Market: wallet share not found");
    require(totalShares < 10000, "ERC1155Market: total share limit exceeded");

    shares[_dealId][ownerShareIndex].share = newShare;
  }

  function addShare(uint _dealId, address payable wallet, uint _share) public {
    Deal memory deal = deals[_dealId];
    require(deal.owner == msg.sender, "ERC1155Market: caller is not deal owner");

    bool doesOwnShare = false;
    uint totalShares = _share;
    for(uint i = 0; i < shares[_dealId].length; i++) {
      if (shares[_dealId][i].wallet == wallet) {
        doesOwnShare = true;
      } else {
        totalShares = totalShares + shares[_dealId][i].share;
      }
    }

    require(!doesOwnShare, "ERC1155Market: wallet already has share");
    require(totalShares < 10000, "ERC1155Market: total share limit exceeded");

    _addShare(DealShare(wallet, _share, 0), _dealId);
  }
}