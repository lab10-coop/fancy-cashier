pragma solidity >=0.5.0 <0.6.0;

import "./IPaymentPolicy.sol";
import "openzeppelin-solidity/contracts/introspection/ERC165Checker.sol";
import "openzeppelin-solidity/contracts/introspection/ERC165.sol";

// partial interfaces for token contracts - includes just the methods we need here

interface IERC20 {
    function balanceOf(address _owner) external view returns (uint256 balance);
    function allowance(address _owner, address _spender) external view returns (uint256);
    function transfer(address _to, uint256 _value) external returns (bool);
    function transferFrom(address _from, address _to, uint256 _value) external returns (bool);
}

interface IERC20_677 {
    function balanceOf(address _owner) external view returns (uint256 balance);
    function transfer(address _to, uint256 _value) external returns (bool);
    function transferAndCall(address receiver, uint amount, bytes calldata data) external returns (bool success);
}

interface IBasicStreamingToken {
    enum AccountType { Default, Concentrator, Deconcentrator }
    function setAccountType(AccountType newType) external;
}


// interface id: 0xa4c0ed36
interface IERC677Receiver {
    function onTokenTransfer(address _from, uint _value, bytes calldata _data) external returns(bool);
}


// A contract implementing this interface must also implement the IERC677Receiver interface
// ERC165 selector id: 0x85a14f6d
// compatible with instances of IPaymentPolicy with ERC165 selector id 0xf74b340a
// contains only the unrestricted interface
interface IFancyCashier {
    function paymentToken() external returns(IERC20_677);
    function discountToken() external returns(IERC20);
    function paymentPolicy() external returns(IPaymentPolicy);
}


/**
 * Depends on the payment token to implement the ERC677 interface.
 * Discounts can be made only to payers who used the ERC20 approve method of the discount token
 * for giving this contract allowance to withdraw them.
 *
 * TODO: accept ERC777 tokens too (they use an alternative receiver callback mechanism)
 */
contract FancyCashier is IERC677Receiver, IFancyCashier, ERC165 {
    // interface id's for ERC165 queries
    bytes4 public constant PAYMENT_POLICY_INTERFACE_ID = 0xf74b340a;
    bytes4 public constant BASIC_STREAMING_TOKEN_INTERFACE_ID = 0xd209f658;

    IERC20_677 public paymentToken;
    IERC20 public discountToken;
    IPaymentPolicy public paymentPolicy;

    address owner;

    event ConfigChanged(string what, address addr);
    event RegisteredPayment(uint256 paymentTokenAmount);
    event Discounted(uint256 discountTokenAmount, uint256 paymentTokenRefundAmount);

    constructor(IERC20_677 _paymentToken, IERC20 _discountToken, IPaymentPolicy _paymentPolicy) public {
        owner = msg.sender;
        setPaymentToken(_paymentToken);
        setDiscountToken(_discountToken);
        setPaymentPolicy(_paymentPolicy);

        // register implemented interfaces for ERC165
        FancyCashier self = this; // workaround to avoid a compiler warnings
        // FancyCashier itself
        _registerInterface(
            self.paymentToken.selector ^
            self.discountToken.selector ^
            self.paymentPolicy.selector
        );
        // IERC677Receiver
        _registerInterface(self.onTokenTransfer.selector);
    }

    modifier onlyOwner {
        require (msg.sender == owner, "no permission");
        _;
    }

    // invoked by ERC677 token contracts when a transfer with this contract as receiver takes place
    // an exception here doesn't mean the transfer can't succeed. That depends on the ERC677 implementation.
    function onTokenTransfer(address _from, uint _value, bytes calldata /* data */) external returns(bool) {
        // only the payment token contract is allowed to call
        require(msg.sender == address(paymentToken), "wrong token");
        require(paymentPolicy.isValidPayment(_from, _value), "payment rejected");

        emit RegisteredPayment(_value);

        (uint256 neededDiscountTokenAmount, uint256 paymentTokenRefundAmount) = paymentPolicy.getApplicableDiscount(_from, _value);
        if(neededDiscountTokenAmount > 0) {
            // check if the payer has enough discount tokens
            if(discountToken.balanceOf(_from) >= neededDiscountTokenAmount) {
                // check if we have allowance for that amount of payer's discount tokens
                if(discountToken.allowance(_from, address(this)) >= neededDiscountTokenAmount) {
                    // fetch discount tokens
                    if(discountToken.transferFrom(_from, address(this), neededDiscountTokenAmount)) {
                        // we made it! now refund the payer accordingly
                        // it should be impossible for this to fail - except for exotic cases
                        // Anyway, in case it does fail, we roll back everything
                        require(paymentToken.transfer(_from, paymentTokenRefundAmount), "refund failed");
                        emit Discounted(neededDiscountTokenAmount, paymentTokenRefundAmount);
                    }
                }
            }
        }
        // if some condition along the way fails, it's all right too. There's just no discount applied then.

        return true;
    }

    // ####################### PRIVILEGED METHODS #######################

    // polymorph method for withdrawing some or all payment tokens, to self or somebody else
    function withdrawPaymentTokens(address receiver, uint256 amount) onlyOwner public {
        paymentToken.transfer(receiver, amount);
    }

    // privileged polymorph method for withdrawing some or all discount tokens, to self or somebody else
    function withdrawDiscountTokens(address receiver, uint256 amount) onlyOwner public {
        discountToken.transfer(receiver, amount);
    }

    // method for withdrawing all tokens of a given token contract (avoid stuck tokens sent here by accident)
    function withdrawAlienTokens(IERC20 token, address receiver) onlyOwner public {
        uint256 fullAmount = token.balanceOf(address(this));
        token.transfer(receiver, fullAmount);
    }


    // methods for re-configuring the contract
    function setOwner(address newOwner) onlyOwner public {
        owner = newOwner;
        emit ConfigChanged("owner", newOwner);
    }

    function setPaymentToken(IERC20_677 _paymentToken) onlyOwner public {
        paymentToken = _paymentToken;

        //
        if(ERC165Checker._supportsInterface(address(_paymentToken), BASIC_STREAMING_TOKEN_INTERFACE_ID)) {
            //IBasicStreamingToken bst = IBasicStreamingToken(address(paymentToken))
            IBasicStreamingToken(address(_paymentToken)).setAccountType(IBasicStreamingToken.AccountType.Concentrator);
        }

        emit ConfigChanged("paymentToken", address(_paymentToken));
    }

    function setDiscountToken(IERC20 _discountToken) onlyOwner public {
        discountToken = _discountToken;
        emit ConfigChanged("discountToken", address(_discountToken));
    }

    function setPaymentPolicy(IPaymentPolicy newPaymentPolicy) onlyOwner public {
        require(ERC165Checker._supportsInterface(address(newPaymentPolicy), PAYMENT_POLICY_INTERFACE_ID), "not a compatible payment policy");
        //require(newPaymentPolicy.supportsInterface(IPAYMENT_POLICY_INTERFACE_ID), "incompatible payment policy");
        paymentPolicy = newPaymentPolicy;
        emit ConfigChanged("paymentPolicy", address(newPaymentPolicy));
    }
}
