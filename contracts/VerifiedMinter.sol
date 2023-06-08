// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract InverseMinterV1 is ERC721, ERC721URIStorage, ERC721Enumerable {
    struct MintOpportunity {
        uint id;
        uint modelId;
        uint mintPrice;
        string tokenURI;
    }

    struct Share {
        address payable wallet;
        uint share;
        uint totalValue;
    }

    address private owner;

    mapping (uint => Share[]) private shares;

    mapping (address => bool) private admins;

    mapping (address => MintOpportunity[]) private minterToMintOpportunities;

    uint private mintIndex = 1;

    function getMintIndex() public view returns(uint) {
        return mintIndex;
    }

    function _incrementMintIndex() internal {
        mintIndex = mintIndex + 1;
    }

    uint private mintOpportunityIndex = 1;

    function getMintOpportunityIndex() public view returns(uint) {
        return mintOpportunityIndex;
    }

    function _incrementMintOpportunityIndex() internal {
        mintOpportunityIndex = mintOpportunityIndex + 1;
    }

    // Manage unique ModelIdss
    uint private modelIndex = 1;

    function getModelIndex() public view returns(uint) {
        return modelIndex;
    }

    function _incrementModelIndex() internal {
        modelIndex = modelIndex + 1;
    }

    mapping (string => uint) private modelIdStringToModelId;

    function getModelId(string memory _modelId) public view returns(uint) {
        return _getModelId(_modelId);
    }

    function _getModelId(string memory _modelId) internal view returns(uint) {
        return modelIdStringToModelId[_modelId];
    }

    function _addModelId(string memory _modelId) internal returns(uint) {
        uint modelId = modelIndex;
        _incrementModelIndex();

        modelIdStringToModelId[_modelId] = modelId;
        return modelId;
    }

    // Manage Admins
    function isAdmin(address _adminAddress) public view returns(bool) {
        return admins[_adminAddress] || false;
    }

    function _addAdmin(address _adminAddress) internal {
        require(msg.sender == owner || isAdmin(msg.sender), "Inverse Minter: sender not authorized to add admin");
        require(!isAdmin(_adminAddress), "Inverse Minter: address is already an admin");

        admins[_adminAddress] = true;
    }

    function _removeAdmin(address _adminAddress) internal {
        require(msg.sender == owner || isAdmin(msg.sender), "Inverse Minter: sender not authorized to remove admin");
        require(isAdmin(_adminAddress), "Inverse Minter: address is not an admin");

        delete admins[_adminAddress];
    }

    function addAdmin(address _adminAddress) public {
        _addAdmin(_adminAddress);
    }

    function removeAdmin(address _adminAddress) public {
        _removeAdmin(_adminAddress);
    }

    // Shares
    function getShares(uint _mintOpportunityId) external view returns(Share[] memory) {
        return _getShares(_mintOpportunityId);
    }

    function _getShares(uint _mintOpportunityId) internal view returns (Share[] memory) {
        return shares[_mintOpportunityId];
    }

    function _addShare(Share memory share, uint _mintOpportunityId) internal {
        shares[_mintOpportunityId].push(share);
    }

    function _removeShares(uint _mintOpportunityId) internal {
        delete shares[_mintOpportunityId];
    }

    // Mint Opportunities
    function _addMintOpportunity(
        address _minter, 
        uint _modelId,
        uint _mintPrice,
        string memory _tokenURI) internal returns(uint) {
        uint id = mintOpportunityIndex;
        _incrementMintOpportunityIndex();

        minterToMintOpportunities[_minter].push(MintOpportunity(id, _modelId, _mintPrice, _tokenURI));
        return id;
    }

    function _getMintOpportunities(address _minter) internal view returns(MintOpportunity[] memory) {
        return minterToMintOpportunities[_minter];
    }

    function _removeMintOpportunity(address _minter, uint _modelId) internal {
        MintOpportunity[] storage mintOpportunities = minterToMintOpportunities[_minter];

        uint valueIndex = mintOpportunities.length;

        for (
            uint index = 0;
            index < mintOpportunities.length && valueIndex == mintOpportunities.length;
            index++
        ) {
            if (mintOpportunities[index].modelId == _modelId) {
                valueIndex = index;
            }
        }

        if (valueIndex < mintOpportunities.length) {
            mintOpportunities[valueIndex] = mintOpportunities[mintOpportunities.length - 1];
            mintOpportunities.pop();
        }
    }

    function _removeMintOpportunityByIndex(address _minter, uint _index) internal {
        MintOpportunity[] storage mintOpportunities = minterToMintOpportunities[_minter];

        mintOpportunities[_index] = mintOpportunities[mintOpportunities.length - 1];
        mintOpportunities.pop();
    }

    function addMintOpportunity(
        address _minterAddress, 
        string memory _tokenURI, 
        uint _price, 
        string memory _modelId,
        address payable[] memory _wallets, 
        uint[] memory _walletShares) external {
        require(msg.sender == owner || isAdmin(msg.sender), "Inverse Minter: sender not authorized to add minter");

        uint totalShares = 0;
        for (uint i = 0; i < _walletShares.length; i++) {
            totalShares = totalShares + _walletShares[i];
        }

        require(totalShares <= 10000, "ERC1155Market: Total shares exceeds maximum 10000 shares");
        require(_walletShares.length == _wallets.length, "ERC1155: Invalid shares");

        uint modelId = getModelId(_modelId);

        if (modelId == 0) {
            modelId = _addModelId(_modelId);
        }
        

        uint mintOpportunityId = _addMintOpportunity(_minterAddress, modelId, _price, _tokenURI);

        for (uint i = 0; i < _walletShares.length; i++) {
            _addShare(Share(_wallets[i], _walletShares[i], 0), mintOpportunityId);
        }
    }
    

    function _beforeTokenTransfer(address from, address to, uint256 tokenId)
        internal
        override(ERC721, ERC721Enumerable)
    {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    constructor() ERC721("InverseMinterV1", "IMV1") {
        owner = msg.sender;
        _addAdmin(msg.sender);
    }

    function mint(string memory _modelId) public payable {
        MintOpportunity[] memory mintOpportunities = _getMintOpportunities(msg.sender);

        require(mintOpportunities.length > 0, "Inverse Minter V1: Unauthorized ");

        uint modelId = _getModelId(_modelId);

        require(modelId != 0, "Inverse Minter V1: Model Id not found for model");

        uint opportunityIndex = mintOpportunities.length;

        for (
            uint index = 0;
            index < mintOpportunities.length && opportunityIndex == mintOpportunities.length;
            index++
        ) {
            if (mintOpportunities[index].modelId == modelId) {
                opportunityIndex = index;
            }
        }

        require(opportunityIndex < mintOpportunities.length, "Inverse Minter V1: Mint opportunity not found");

        MintOpportunity memory mintOpportunity = mintOpportunities[opportunityIndex];

        if (mintOpportunity.mintPrice > 0) {
            bool paid = true;    
            uint remainingValue = mintOpportunity.mintPrice;
            uint mintOpportunityId = mintOpportunity.id;
            
            for (uint i; i < shares[mintOpportunityId].length; i++) {
                Share memory share = shares[mintOpportunityId][i];
                uint shareAmount = (mintOpportunity.mintPrice * share.share) / 10000;
                if (shareAmount > 0) {
                    bool sharePaid = share.wallet.send(shareAmount);
                    paid = paid && sharePaid;
                    remainingValue = remainingValue - shareAmount;
                    share.totalValue = share.totalValue + shareAmount;

                    shares[mintOpportunityId][i] = share;
                }
            }
            bool ownerPaid = true;

            if (remainingValue > 0) {
                ownerPaid = payable(owner).send(remainingValue);
            }

            require(paid && ownerPaid, "Inverse Minter V1: payment failed");
        }

        _safeMint(msg.sender, mintIndex);
        _setTokenURI(mintIndex, mintOpportunity.tokenURI);
        _removeMintOpportunityByIndex(msg.sender, opportunityIndex);
        _incrementMintIndex();
    }

    function ownerMint(string memory _uri) public payable {
        require(minterToMintOpportunities[msg.sender].length > 0, "Inverse Minter V1: Unauthorized ");   

        _safeMint(msg.sender, mintIndex);
        _setTokenURI(mintIndex, _uri);
        _incrementMintIndex();
    }
}
