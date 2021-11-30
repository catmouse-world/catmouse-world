// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.0;
import "./Ownable.sol";
import "./Pausable.sol";
import "./ERC721Enumerable.sol";
import "./ERC20.sol";

interface Random {
    function getRandom(uint256 seed, uint256 range) external view returns (uint256);
    function addNonce() external;
}

interface PrizePool {
    function getTotalPower() external view returns (uint256);
}

contract WoolPouch is ERC721Enumerable, Ownable, Pausable {
    Random public random;
    uint16 public minted;
    address public woolAddress = 0xA46346bC9d110907b5ACE36B53263320baf1cD21;
    address public prizeAddress = 0x000000000000000000000000000000000000dEaD;

    constructor() ERC721 ("Wolf Game DAO Wool Pouch", "WOOLP") {}

    struct Pouch {
        uint16 rarity;
        uint16 booster;
        bool opened;
    }

    struct Payout {
        uint256 minPayout;
        uint256 maxPayout;
    }

    mapping(uint16 => Pouch) Pouches;
    mapping(uint16 => uint256) woolClaimed;

    mapping(uint16 => Payout) PouchPayouts; //rarity => payout

    function open(uint16 id) public whenNotPaused {
        require(tx.origin == _msgSender(), "Only from EOA");
        require(Pouches[id].opened == false, "Pouch already opened.");
        require(id > 0, "Token ID illegal");
        ERC721(address(this)).safeTransferFrom(_msgSender(), 0x000000000000000000000000000000000000dEaD, id);
        uint16 rarity = Pouches[id].rarity;
        uint16 booster = Pouches[id].booster;
        uint256 payout = _calcPayout(rarity, booster);
        Pouches[id].opened = true;
        woolClaimed[id] = payout;
        ERC20(woolAddress).transfer(_msgSender(), payout);
    }

    function _calcPayout(uint16 rarity, uint16 booster) internal returns (uint256) {
        uint256 totalPrize = _getPrizePool();
        uint256 totalPower = _getTotalPower();
        uint256 baseNumber = totalPrize / totalPower;
        uint256 seed = random.getRandom(minted, 10000) + 1;
        random.addNonce();
        uint256 payout = 0;
        if (rarity == 0) {
            payout = baseNumber * seed / 10000; // rarity 0 payout
        } else {
            payout = PouchPayouts[rarity].maxPayout * seed / 10000; // rarity 1 2
            if (payout < PouchPayouts[rarity].minPayout) {
                payout = PouchPayouts[rarity].minPayout;
            }
        }
        return payout * booster;
    }

    function _getPrizePool() internal view returns (uint256) {
        ERC20 wool = ERC20(woolAddress);
        return wool.balanceOf(prizeAddress);
    }

    function _getTotalPower() internal view returns (uint256) {
        PrizePool pool = PrizePool(prizeAddress);
        return pool.getTotalPower();
    }

    function setWoolAddress(address _newAddr) external onlyOwner {
        woolAddress = _newAddr;
    }

    function setPrizeAddress(address _newAddr) external onlyOwner {
        woolAddress = _newAddr;
    }

    function setPouchPayouts(uint16 rarity, uint256 _min, uint256 _max) external onlyOwner {
        PouchPayouts[rarity].minPayout = _min;
        PouchPayouts[rarity].maxPayout = _max;
    }

    function withdrawERC721(address _token, uint _id, address _to) public onlyOwner {
        IERC721 token = IERC721(_token);
        token.safeTransferFrom(address(this), _to, _id);
    }
    
    function withdraw(address _token, address _to) public onlyOwner{
        if (_token == address(0x0)) {
            payable(_to).transfer(address(this).balance);
            return;
        }
        
        ERC20 token = ERC20(_token);
        token.transfer(_to, token.balanceOf(address(this)));
    }

    function setPaused(bool _paused) external onlyOwner {
        if (_paused) _pause();
        else _unpause();
    }
}
    