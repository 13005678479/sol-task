// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title MetaNodeToken
 * @dev ERC20 token for MetaNode staking rewards
 * @author MetaNode Task
 */
contract MetaNodeToken is ERC20, Ownable {
    
    // Mint control
    uint256 public maxSupply;
    bool public mintingEnabled;
    
    // Events
    event MintingStatusChanged(bool enabled);
    event MaxSupplyUpdated(uint256 oldMaxSupply, uint256 newMaxSupply);
    
    // Errors
    error MintingDisabled();
    error MaxSupplyReached(uint256 current, uint256 requested);
    error ZeroAddress();
    error InvalidAmount(uint256 amount);
    
    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _initialSupply,
        uint256 _maxSupply
    ) ERC20(_name, _symbol) {
        require(_maxSupply >= _initialSupply, "Max supply must be >= initial supply");
        
        maxSupply = _maxSupply;
        mintingEnabled = true;
        
        if (_initialSupply > 0) {
            _mint(msg.sender, _initialSupply);
        }
    }
    
    /**
     * @dev Mint new tokens (only owner)
     * @param to Recipient address
     * @param amount Amount to mint
     */
    function mint(address to, uint256 amount) external onlyOwner {
        if (!mintingEnabled) revert MintingDisabled();
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert InvalidAmount(amount);
        
        uint256 currentSupply = totalSupply();
        if (currentSupply + amount > maxSupply) {
            revert MaxSupplyReached(currentSupply, amount);
        }
        
        _mint(to, amount);
    }
    
    /**
     * @dev Burn tokens
     * @param amount Amount to burn
     */
    function burn(uint256 amount) external {
        if (amount == 0) revert InvalidAmount(amount);
        _burn(msg.sender, amount);
    }
    
    /**
     * @dev Enable/disable minting
     * @param _enabled Minting status
     */
    function setMintingEnabled(bool _enabled) external onlyOwner {
        mintingEnabled = _enabled;
        emit MintingStatusChanged(_enabled);
    }
    
    /**
     * @dev Update max supply
     * @param _newMaxSupply New maximum supply
     */
    function updateMaxSupply(uint256 _newMaxSupply) external onlyOwner {
        require(_newMaxSupply >= totalSupply(), "New max supply must be >= current supply");
        uint256 oldMaxSupply = maxSupply;
        maxSupply = _newMaxSupply;
        emit MaxSupplyUpdated(oldMaxSupply, _newMaxSupply);
    }
    
    /**
     * @dev Get current minting status
     */
    function isMintingEnabled() external view returns (bool) {
        return mintingEnabled;
    }
    
    /**
     * @dev Get remaining mintable supply
     */
    function remainingSupply() external view returns (uint256) {
        return maxSupply - totalSupply();
    }
}