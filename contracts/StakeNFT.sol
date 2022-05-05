//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";


contract NFTStake is ERC20{
    
    struct Stake{
        uint256 tokenId;
        uint256 blocknumber;
        address owner;
    }

    uint256 public s_totalStaked;
    uint256 public s_rewardPerBlock = 0.1 ether;
    address s_nft;

    ERC721 public s_nft_contract = ERC721(s_nft);

    mapping(uint256 => Stake) public s_vault;


    constructor(address nft) ERC20("Coins", "CO") {
        s_nft = nft;
    }

    // puede hacer stake de varios
    // si ya existe se le agrega 
    function stakeNFT(uint256[] calldata tokenIds) public{
        
        uint256 tokenId;
        //suma cantidad de stakes
        s_totalStaked += tokenIds.length;
        uint256 tokenIdsLen = tokenIds.length;
        ERC721 nft = s_nft_contract;

        //creo maps para cada nft con info de su owner
        for(uint256 i = 0; i < tokenIdsLen; i++){
            tokenId = tokenIds[i];

            require(nft.ownerOf(tokenId) == msg.sender, "not your token");

            require(s_vault[tokenId].tokenId == 0, 'already staked');

            nft.transferFrom(msg.sender, address(this), tokenId);

            s_vault[tokenId] = Stake(tokenId, block.number, msg.sender);
        }
    }

    
    function _unstakeMany(address account, uint256[] calldata tokenIds) internal {
        
        uint256 tokenId;
        //resto del total de stakes
        s_totalStaked -= tokenIds.length;
        uint256 tokenIdsLen = tokenIds.length;
        Stake memory staked;
        ERC721 nft = s_nft_contract;

        for (uint i = 0; i < tokenIdsLen; i++) {
            
            tokenId = tokenIds[i];

            //se realiza la copia de la estructura
            staked = s_vault[tokenId];
            //verifico que sea el owner el que quiera retirar su nft 
            require(staked.owner == msg.sender, "not an owner");

            //se borra la cuenta
            delete s_vault[tokenId];
      
            //se manda el nft al duenio
            nft.transferFrom(address(this), account, tokenId);
        }
    }

    //funcion que obtiene recompenza sin sacar stake
    function claim(uint256[] calldata tokenIds) external {
        _claim(msg.sender, tokenIds, false);
    }

    //funcion que retira las recompenzas y el stake
    function unstake(uint256[] calldata tokenIds) external {
        _claim(msg.sender, tokenIds, true);
    }

    function _claim(address account, uint256[] calldata tokenIds, bool _unstake) internal {
        uint256 tokenId;
        uint256 reward;
        uint256 tokenIdsLen = tokenIds.length;  
        Stake memory staked;
        uint256 rewardPerBlock = s_rewardPerBlock;
        uint256 checkpoints;

        for (uint i = 0; i < tokenIdsLen; i++) {
            tokenId = tokenIds[i];

            staked = s_vault[tokenId];
            require(staked.owner == msg.sender, "not an owner");

            //calcula ganancias 
            checkpoints = staked.blocknumber;
            reward += rewardPerBlock * (block.number - checkpoints);

            //reinicia cuenta
            s_vault[tokenId] = Stake(tokenId, block.number, account);
        }
        if (reward > 0) {

            //se reparte la ganancia 
            _mint(account, reward);
        }
        // si es true se unstekea
        if (_unstake) {
            _unstakeMany(account, tokenIds);
        }
    }

    function calculateReward(uint256[] calldata tokenIds) public view returns(uint256){

        uint256 tokenId;
        uint256 reward;
        Stake memory staked;
        uint256 checkpoints;
        uint256 rewardPerBlock = s_rewardPerBlock;
        
        for (uint i = 0; i < tokenIds.length; i++) {
            tokenId = tokenIds[i];

            staked = s_vault[tokenId];
            require(staked.owner == msg.sender, "not an owner");

            //calcula ganancias 
            checkpoints = staked.blocknumber;
            reward += rewardPerBlock * (block.number - checkpoints);
        }
        return reward;
    }
}