pragma solidity ^0.8.9;
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155URIStorage.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";

contract Tickets is ERC1155, ERC1155Supply, ERC1155URIStorage, ERC1155Holder {
  // Members
  uint private tokenIndex = 1;

  mapping (uint => uint) private ticketToEvents;

  mapping (uint => uint) private stubsToTickets;

  mapping (uint => uint) private ticketsToStubs;

  mapping (uint => bool) private events;

  mapping (uint => uint[]) private eventsToTickets;

  // Events
  event UseTicket(address indexed sender, uint indexed eventTokenId, uint indexed ticketTokenId);

  event TicketsMinted(uint indexed eventTokenId, uint indexed ticketsTokenId);

  event EventMinted(address indexed minter, uint indexed eventTokenId);

  event StubsMinted (uint indexed ticketTokenId, uint indexed stubTokenId);

  constructor () ERC1155("EventTicketing") {}

  // Mint Index
  function getTokenIndex() public view returns(uint) {
      return tokenIndex;
  }

  function _incrementTokenIndex() internal {
      tokenIndex = tokenIndex + 1;
  }

  // Managing Tickets to Events
  function getTicketEvent(uint _id) external view returns(uint) {
    return _getTicketEvent(_id);
  }

  function _getTicketEvent(uint _id) internal view returns(uint) {
    return ticketToEvents[_id];
  }

  function _addTicketsToEvents(uint _id, uint _eventId) internal {
    if (events[_eventId] && !events[_id]) {
      ticketToEvents[_id] = _eventId;
    }
  }

  function _removeTicketsToEvents(uint _id) internal {
    delete ticketToEvents[_id];
  }

  // Managing Stubs to Tickets
  function getStubTicket(uint _stubId) external view returns(uint) {
    return _getStubTicket(_stubId);
  }

  function _getStubTicket(uint _stubId) internal view returns(uint) {
    return stubsToTickets[_stubId];
  }

  function _addStubToTicket(uint _stubId, uint _ticketId) internal {
    if (ticketToEvents[_ticketId] != 0 && stubsToTickets[_stubId] == 0) {
      stubsToTickets[_stubId] = _ticketId;
    }
  }

  // Manage Tickets to Stubs
  function getTicketStub(uint _ticketId) external view returns(uint) {
    return _getTicketStub(_ticketId);
  }

  function _getTicketStub(uint _ticketId) internal view returns(uint) {
    return ticketsToStubs[_ticketId];
  }

  function _addTicketToStub(uint _ticketId, uint _stubId) internal {
    if (ticketsToStubs[_ticketId] == 0) {
      ticketsToStubs[_ticketId] = _stubId;
    }
  }

  // Manage Stubs
  function _addStub(uint _stubId, uint _ticketId) internal {
    _addTicketToStub(_ticketId, _stubId);
    _addStubToTicket(_stubId, _ticketId);
  }

  function getStubEvent(uint _stubId) external view returns(uint) {
    uint ticketId = _getStubTicket(_stubId);
    return _getTicketEvent(ticketId);
  }

  // Managing events
  function isTokenEvent(uint _id) external view returns(bool) {
    return _isTokenEvent(_id);
  }

  function _isTokenEvent(uint _id) internal view returns(bool) {
    return events[_id] || false;
  }

  function _addEvent(uint _id) internal {
    if (totalSupply(_id) == 1 && !events[_id]) {
      events[_id] = true;
    }
  }

  function _removeEvent(uint _id) internal {
    delete events[_id];
  }

  // Managing events to tickets
  function getEventTickets(uint _eventId) external view returns(uint[] memory) {
    return _getEventTickets(_eventId);
  }

  function _getEventTickets(uint _eventId) internal view returns(uint[] memory) {
    return eventsToTickets[_eventId];
  }

  function _addTicketToEvent(uint _eventId, uint _ticketId) internal {
    eventsToTickets[_eventId].push(_ticketId);
  }

  // Controls 
  function mintEvent(string memory _metadataURI) public {
    uint eventTokenId = tokenIndex;
    _incrementTokenIndex();

    _mint(msg.sender, eventTokenId, 1, "");
    _setURI(eventTokenId, _metadataURI);
    _addEvent(eventTokenId);

    emit EventMinted(msg.sender, eventTokenId);
  }

  function mintTickets(uint _eventTokenId, string memory _metadataURI, uint _supply) public {
    require(_isTokenEvent(_eventTokenId), "EventTicketing: invalid event");
    require(balanceOf(msg.sender, _eventTokenId) > 0, "EventTicketing: unauthorized to mint tickets for event");
    uint ticketTokenId = tokenIndex;
    _incrementTokenIndex();

    _mint(msg.sender, ticketTokenId, _supply, "");
    _setURI(ticketTokenId, _metadataURI);
    _addTicketsToEvents(ticketTokenId, _eventTokenId);
    _addTicketToEvent(_eventTokenId, ticketTokenId);

    emit TicketsMinted(_eventTokenId, ticketTokenId);

    _mintStubs(ticketTokenId, _metadataURI, _supply);
  }

  function _mintStubs(uint _ticketId, string memory _metadataURI, uint _supply) internal {
    uint stubTokenId = tokenIndex;
    _incrementTokenIndex();

    _mint(address(this), stubTokenId, _supply, "");
    _setURI(stubTokenId, _metadataURI);
    _addStub(stubTokenId, _ticketId);

    emit StubsMinted(_ticketId, stubTokenId);
  }

  function increaseTicketSupply(uint _ticketId, uint _supply) external {
    uint eventId = _getTicketEvent(_ticketId);
    require(eventId != 0, "EventTicketing: no event found for this ticket token");
    require(balanceOf(msg.sender, eventId) == 1, "EventTicketing: sender does not own event");
    
    _mint(msg.sender, _ticketId, _supply, "");
    
    emit TicketsMinted(eventId, _ticketId);

    _increaseStubSupply(_ticketId, _supply);
  }

  function _increaseStubSupply(uint _ticketId, uint _supply) internal {
    uint stubId = _getTicketStub(_ticketId);

    _mint(address(this), stubId, _supply, "");

    emit StubsMinted(_ticketId, stubId);
  }

  function useTicket(uint _ticketTokenId) public {
    uint eventTokenId = _getTicketEvent(_ticketTokenId);
    uint stubTokenId = _getTicketStub(_ticketTokenId);
  
    require(balanceOf(msg.sender, _ticketTokenId) > 0, "EventTicketing: no ticket found");
    require(stubTokenId != 0, "EventTicketing: no ticket stub found for this ticket");
    require(eventTokenId != 0, "EventTicketing: no event for this ticket token");
  
    _burn(msg.sender, _ticketTokenId, 1);
    _safeTransferFrom(address(this), msg.sender, stubTokenId, 1, "");

    emit UseTicket(msg.sender, eventTokenId, _ticketTokenId);
  }

  function updateURI(uint _ticketId, string memory _metadataURI) public {
    uint eventId = _getTicketEvent(_ticketId);
    require(eventId != 0, "EventTicketing: no event found for this ticket token");
    require(balanceOf(msg.sender, eventId) == 1, "EventTicketing: sender does not own event");

    _setURI(_ticketId, _metadataURI);
  }

  // Overrides

  function _containsStubs(uint[] memory _ids) internal view returns(bool) {
    for (uint i = 0; i < _ids.length; i++) {
      if (stubsToTickets[_ids[i]] != 0) {
        return true;
      }
    }
    return false;
  }

  function _beforeTokenTransfer(address operator, address from, address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data)
    internal
    override(ERC1155, ERC1155Supply)
  {
    require(!_containsStubs(ids) || to == address(this) || from == address(this), "EventTicketing: cannot transfer stubs");
    super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
  }

  function uri(uint256 tokenId) public view virtual override(ERC1155, ERC1155URIStorage) returns (string memory) {
    return super.uri(tokenId);
  }

  function supportsInterface(bytes4 interfaceId) public view virtual override(ERC1155, ERC1155Receiver) returns (bool) {
    return super.supportsInterface(interfaceId);
  }
}
