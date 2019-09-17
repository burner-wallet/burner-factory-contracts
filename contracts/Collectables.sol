pragma solidity ^0.5.0;

import 'openzeppelin-solidity/contracts/token/ERC721/ERC721Full.sol';
import 'openzeppelin-solidity/contracts/ownership/Ownable.sol';
import 'openzeppelin-solidity/contracts/math/SafeMath.sol';

contract Collectables is ERC721Full, Ownable {
    using SafeMath for uint256;

    struct Collectable {
        uint256 numClonesAllowed;
        uint256 numClonesInWild;
        uint256 clonedFromId;
    }

    Collectable[] public collectables;
    bool public isMintable = true;
    string public uriPrefix;

    modifier mintable {
        require(
            isMintable == true,
            "New collectables are no longer mintable on this contract.  Please see KUDOS_CONTRACT_MAINNET at http://gitcoin.co/l/gcsettings for latest address."
        );
        _;
    }

    constructor(string memory name, string memory symbol, string memory _uriPrefix) public ERC721Full(name, symbol) {
        uriPrefix = _uriPrefix;
        // If the array is new, skip over the first index.
        if(collectables.length == 0) {
            Collectable memory _dummyCollectable = Collectable({ numClonesAllowed: 0, numClonesInWild: 0, clonedFromId: 0 });
            collectables.push(_dummyCollectable);
        }
    }

    function tokenURI(uint256 tokenId) external view returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");
        return string(abi.encodePacked(uriPrefix, "0x", toAsciiString(address(this)), "/", uint2str(tokenId)));
    }

    /// @dev mint(): Mint a new Gen0 Collectables.  These are the tokens that other Collectables will be "cloned from".
    /// @param _to Address to mint to.
    /// @param _numClonesAllowed Maximum number of times this Collectables is allowed to be cloned.
    /// @return the tokenId of the Collectables that has been minted.  Note that in a transaction only the tx_hash is returned.
    function mint(address _to, uint256 _numClonesAllowed) public mintable onlyOwner returns (uint256 tokenId) {

        Collectable memory _collectable = Collectable({ numClonesAllowed: _numClonesAllowed, numClonesInWild: 0, clonedFromId: 0 });
        // The new collectable is pushed onto the array and minted
        // Note that Solidity uses 0 as a default value when an item is not found in a mapping.

        tokenId = collectables.push(_collectable) - 1;
        collectables[tokenId].clonedFromId = tokenId;

        _mint(_to, tokenId);
    }

    /// @dev clone(): Clone a new Collectables from a Gen0 Collectables.
    /// @param _to The address to clone to.
    /// @param _tokenId The token id of the Collectables to clone and transfer.
    function clone(address _to, uint256 _tokenId) public mintable {
        // Grab existing Collectable blueprint
        Collectable memory _collectable = collectables[_tokenId];
        require(
            _collectable.numClonesInWild < _collectable.numClonesAllowed,
            "The number of Collectables clones requested exceeds the number of clones allowed.");

        // Update original collectable struct in the array
        _collectable.numClonesInWild += 1;

        collectables[_tokenId] = _collectable;
        Collectable memory _newCollectable;
        _newCollectable.numClonesAllowed = 0;
        _newCollectable.numClonesInWild = 0;
        _newCollectable.clonedFromId = _tokenId;

        // Note that Solidity uses 0 as a default value when an item is not found in a mapping.
        uint256 newTokenId = collectables.push(_newCollectable) - 1;

        // Mint the new collectables to the _to account
        _mint(_to, newTokenId);
    }


    /// @dev burn(): Burn Collectables token.
    /// @param _owner The owner address of the token to burn.
    /// @param _tokenId The Collectables ID to be burned.
    function burn(address _owner, uint256 _tokenId) public onlyOwner {
        Collectable memory _collectable = collectables[_tokenId];
        uint256 gen0Id = _collectable.clonedFromId;
        if (_tokenId != gen0Id) {
            Collectable memory _gen0Collectable = collectables[gen0Id];
            _gen0Collectable.numClonesInWild -= 1;
            collectables[gen0Id] = _gen0Collectable;
        }
        delete collectables[_tokenId];
        _burn(_owner, _tokenId);
    }

    /// @dev setMintable(): set the isMintable public variable.  When set to `false`, no new 
    ///                     collectables are allowed to be minted or cloned.  However, all of already
    ///                     existing collectables will remain unchanged.
    /// @param _isMintable flag for the mintable function modifier.
    function setMintable(bool _isMintable) public onlyOwner {
        isMintable = _isMintable;
    }

    /// @dev getCollectablesById(): Return a Collectables struct/array given a Collectables Id. 
    /// @param _tokenId The Collectables Id.
    /// @return the Collectables struct, in array form.
    function getCollectablesById(uint256 _tokenId) view public returns (uint256 numClonesAllowed,
                                                                uint256 numClonesInWild,
                                                                uint256 clonedFromId
                                                                )
    {
        Collectable memory _collectable = collectables[_tokenId];

        numClonesAllowed = _collectable.numClonesAllowed;
        numClonesInWild = _collectable.numClonesInWild;
        clonedFromId = _collectable.clonedFromId;
    }

    /// @dev getNumClonesInWild(): Return a Collectables struct/array given a Collectables Id. 
    /// @param _tokenId The Collectables Id.
    /// @return the number of cloes in the wild
    function getNumClonesInWild(uint256 _tokenId) view public returns (uint256 numClonesInWild)
    {   
        Collectable memory _collectable = collectables[_tokenId];

        numClonesInWild = _collectable.numClonesInWild;
    }

    /// @dev getLatestId(): Returns the newest Collectables Id in the collectables array.
    /// @return the latest collectables id.
    function getLatestId() view public returns (uint256 tokenId)
    {
        if (collectables.length == 0) {
            tokenId = 0;
        } else {
            tokenId = collectables.length - 1;
        }
    }

    function toAsciiString(address x) internal pure returns (string memory) {
        bytes memory s = new bytes(40);
        for (uint i = 0; i < 20; i++) {
            byte b = byte(uint8(uint(x) / (2**(8*(19 - i)))));
            byte hi = byte(uint8(b) / 16);
            byte lo = byte(uint8(b) - 16 * uint8(hi));
            s[2*i] = char(hi);
            s[2*i+1] = char(lo);            
        }
        return string(s);
    }

    function char(byte b) internal pure returns (byte c) {
        if (uint8(b) < 10) return byte(uint8(b) + 0x30);
        else return byte(uint8(b) + 0x57);
    }

    function uint2str(uint i) internal pure returns (string memory) {
        if (i == 0) return "0";
        uint j = i;
        uint len;
        while (j != 0){
            len++;
            j /= 10;
        }
        bytes memory bstr = new bytes(len);
        uint k = len - 1;
        while (i != 0){
            bstr[k--] = byte(uint8(48 + i % 10));
            i /= 10;
        }
        return string(bstr);
    }
}
