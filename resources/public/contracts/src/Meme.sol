pragma solidity ^0.4.18;

import "RegistryEntry.sol";
import "MemeToken.sol";
import "forwarder/Forwarder.sol";

contract Meme is RegistryEntry {

  bytes32 public constant maxStartPriceKey = sha3("maxStartPrice");
  bytes32 public constant maxTotalSupplyKey = sha3("maxTotalSupply");
  bytes32 public constant saleDurationKey = sha3("saleDuration");
  MemeToken token;
  bytes imageHash;
  bytes metaHash;
  uint startPrice;
  uint saleDuration;

  function construct(
    address _creator,
    uint _version,
    string _name,
    bytes _imageHash,
    bytes _metaHash,
    uint _totalSupply,
    uint _startPrice
  )
  public
  {
    super.construct(_creator, _version);

    require(_totalSupply > 0);
    require(_totalSupply <= registry.db().getUIntValue(maxTotalSupplyKey));
    token = MemeToken(new Forwarder());
    token.construct(_name);
    token.mint(this, _totalSupply);
    token.finishMinting();

    imageHash = _imageHash;
    metaHash = _metaHash;

    require(_startPrice <= registry.db().getUIntValue(maxStartPriceKey));
    startPrice = _startPrice;
    saleDuration = registry.db().getUIntValue(saleDurationKey);
  }

  function buy(uint _amount)
  payable
  public
  notEmergency
  onlyConstructed
  {
    require(isWhitelisted());
    require(_amount > 0);

    var price = currentPrice().mul(_amount);

    require(msg.value >= price);
    require(token.transfer(msg.sender, _amount));
    creator.transfer(price);
    if (msg.value > price) {
      msg.sender.transfer(msg.value.sub(price));
    }
    registry.fireRegistryEntryEvent("buy", version);
  }

  function currentPrice() constant returns (uint) {
    uint secondsPassed = 0;
    uint listedOn = whitelistedOn();

    if (now > listedOn && listedOn > 0) {
      secondsPassed = now.sub(listedOn);
    }

    return computeCurrentPrice(
      startPrice,
      saleDuration,
      secondsPassed
    );
  }

  function computeCurrentPrice(uint _startPrice, uint _duration, uint _secondsPassed) constant returns (uint) {
    if (_secondsPassed >= _duration) {
      // We've reached the end of the dynamic pricing portion
      // of the auction, just return the end price.
      return 0;
    } else {
      // Starting price can be higher than ending price (and often is!), so
      // this delta can be negative.
      int totalPriceChange = 0 - int(_startPrice);

      // This multiplication can't overflow, _secondsPassed will easily fit within
      // 64-bits, and totalPriceChange will easily fit within 128-bits, their product
      // will always fit within -bits.
      int currentPriceChange = totalPriceChange * int(_secondsPassed) / int(_duration);

      // currentPriceChange can be negative, but if so, will have a magnitude
      // less that _startingPrice. Thus, this result will always end up positive.
      int currentPrice = int(_startPrice) + currentPriceChange;

      return uint(currentPrice);
    }
  }

  function loadMeme() public constant returns (uint, uint, address, bytes, bytes) {
    return (
    startPrice,
    saleDuration,
    token,
    imageHash,
    metaHash
    );
  }
}