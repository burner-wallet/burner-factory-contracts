pragma solidity ^0.5.0;

import 'openzeppelin-solidity/contracts/token/ERC721/IERC721Full.sol';

contract ICollectables is IERC721Full {
  function tokenURI(uint256 tokenId) external view returns (string memory);

  /// @dev mint(): Mint a new Gen0 Collectables.  These are the tokens that other Collectables will be "cloned from".
  /// @param _to Address to mint to.
  /// @param _numClonesAllowed Maximum number of times this Collectables is allowed to be cloned.
  /// @return the tokenId of the Collectables that has been minted.  Note that in a transaction only the tx_hash is returned.
  function mint(address _to, uint256 _numClonesAllowed) public returns (uint256 tokenId);

  /// @dev clone(): Clone a new Collectables from a Gen0 Collectables.
  /// @param _to The address to clone to.
  /// @param _tokenId The token id of the Collectables to clone and transfer.
  function clone(address _to, uint256 _tokenId) public;

  function getClonedTokenByAddress(address user, uint256 baseToken) public view returns (uint256);

  /// @dev burn(): Burn Collectables token.
  /// @param _owner The owner address of the token to burn.
  /// @param _tokenId The Collectables ID to be burned.
  function burn(address _owner, uint256 _tokenId) public;

  /// @dev setMintable(): set the isMintable public variable.  When set to `false`, no new 
  ///                     collectables are allowed to be minted or cloned.  However, all of already
  ///                     existing collectables will remain unchanged.
  /// @param _isMintable flag for the mintable function modifier.
  function setMintable(bool _isMintable) public;

  /// @dev getCollectablesById(): Return a Collectables struct/array given a Collectables Id. 
  /// @param _tokenId The Collectables Id.
  /// @return the Collectables struct, in array form.
  function getCollectablesById(uint256 _tokenId) view public
    returns (uint256 numClonesAllowed,  uint256 numClonesInWild, uint256 clonedFromId);

  /// @dev getNumClonesInWild(): Return a Collectables struct/array given a Collectables Id. 
  /// @param _tokenId The Collectables Id.
  /// @return the number of cloes in the wild
  function getNumClonesInWild(uint256 _tokenId) view public returns (uint256 numClonesInWild);

  /// @dev getLatestId(): Returns the newest Collectables Id in the collectables array.
  /// @return the latest collectables id.
  function getLatestId() view public returns (uint256 tokenId);
}
