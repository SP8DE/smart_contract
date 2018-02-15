pragma solidity ^0.4.18;

import './SafeMath.sol';
import './SPXToken.sol';

/**
 * @title Spade SpadeIco
 */
contract SpadeIco {
  
  uint public constant TOKENS_FOR_SALE = 3655555558 * 1e18;
  uint public constant TOKENS_FOUNDATION = 1777777778 * 1e18;
  
  uint tokensSold = 0;
  
  // Ico token
  SPXToken public token;
  address public team;
  address public icoAgent;
  address public migrationMaster;
  // Modifiers
  modifier teamOnly {require(msg.sender == team); _;}
  modifier icoAgentOnly {require(msg.sender == icoAgent); _;}
  
  bool public isPaused = false;
  enum IcoState { Created, IcoStarted, IcoFinished }
  IcoState public icoState = IcoState.Created;

  event IcoStarted();
  event IcoFinished();
  event IcoPaused();
  event IcoResumed();
  event TokenBuy(address indexed buyer, uint256 tokens, uint256 factor, string tx);
  event TokenBuyPresale(address indexed buyer, uint256 tokens, uint256 factor, string tx);
  event TokenWin(address indexed buyer, uint256 tokens, uint256 jackpot);

  function SpadeIco(address _team, address _icoAgent, address _migrationMaster) public {
    require(_team != address(0) && _icoAgent != address(0) && _migrationMaster != address(0));  
    migrationMaster = _migrationMaster;
    team = _team;
    icoAgent = _icoAgent;
    token = new SPXToken(this, migrationMaster);
  }

  function startIco() external teamOnly {
    require(icoState == IcoState.Created);
    icoState = IcoState.IcoStarted;
    IcoStarted();
  }

  function finishIco(address foundation, address other) external teamOnly {
    require(foundation != address(0));
    require(other != address(0));

    require(icoState == IcoState.IcoStarted);
    icoState = IcoState.IcoFinished;
    
    uint256 amountWithFoundation = SafeMath.add(token.totalSupply(), TOKENS_FOUNDATION);
    if (amountWithFoundation > token.TOKEN_LIMIT()) {
      uint256 foundationToMint = token.TOKEN_LIMIT() - token.totalSupply();
      if (foundationToMint > 0) {
        token.mint(foundation, foundationToMint);
      }
    } else {
        token.mint(foundation, TOKENS_FOUNDATION);

        uint mintedTokens = token.totalSupply();
    
        uint remaining = token.TOKEN_LIMIT() - mintedTokens;
        if (remaining > 0) {
          token.mint(other, remaining);
        }
    }

    token.unfreeze();
    IcoFinished();
  }

  function pauseIco() external teamOnly {
    require(!isPaused);
    require(icoState == IcoState.IcoStarted);
    isPaused = true;
    IcoPaused();
  }

  function resumeIco() external teamOnly {
    require(isPaused);
    require(icoState == IcoState.IcoStarted);
    isPaused = false;
    IcoResumed();
  }

  function convertPresaleTokens(address buyer, uint256 tokens, uint256 factor, string txHash) external icoAgentOnly returns (uint) {
    require(buyer != address(0));
    require(tokens > 0);
    require(validState());

    uint256 tokensToSell = SafeMath.add(tokensSold, tokens);
    require(tokensToSell <= TOKENS_FOR_SALE);
    tokensSold = tokensToSell;            

    token.mint(buyer, tokens);
    TokenBuyPresale(buyer, tokens, factor, txHash);
  }

  function creditJackpotTokens(address buyer, uint256 tokens, uint256 jackpot) external icoAgentOnly returns (uint) {
    require(buyer != address(0));
    require(tokens > 0);
    require(validState());

    token.mint(buyer, tokens);
    TokenWin(buyer, tokens, jackpot);
  }

  function buyTokens(address buyer, uint256 tokens, uint256 factor, string txHash) external icoAgentOnly returns (uint) {
    require(buyer != address(0));
    require(tokens > 0);
    require(validState());

    uint256 tokensToSell = SafeMath.add(tokensSold, tokens);
    require(tokensToSell <= TOKENS_FOR_SALE);
    tokensSold = tokensToSell;            

    token.mint(buyer, tokens);
    TokenBuy(buyer, tokens, factor, txHash);
  }

  function validState() internal view returns (bool) {
    return icoState == IcoState.IcoStarted && !isPaused;
  }
}