pragma solidity >=0.5.0 <0.6.0;

import "./IPaymentPolicy.sol";

// Standard Interface Detection - see https://eips.ethereum.org/EIPS/eip-165
interface IERC165 {
    function supportsInterface(bytes4 interfaceID) external view returns (bool);
}

contract Lab10DrinksPaymentPolicy is IPaymentPolicy, IERC165 {
    uint256 constant MIN_PAYMENT_AMOUNT = 2E18;

    // min amount: 2 units
    function isValidPayment(address, uint256 amount) external view returns(bool) {
        return amount >= MIN_PAYMENT_AMOUNT;
    }

    // discount of 1 unit for 2 units of discount tokens
    function getApplicableDiscount(address, uint256 paymentAmount) external view
        returns(uint256 neededDiscountTokenAmount, uint256 paymentTokenRefundAmount)
    {
        if(paymentAmount >= MIN_PAYMENT_AMOUNT) {
            return (2E18, 1E18);
        }
        // amount insufficient for a discount
        return (0, 0);
    }

    // ERC165 interface detection
    function supportsInterface(bytes4 interfaceID) external view returns (bool) {
        return
            interfaceID == this.supportsInterface.selector || // ERC165
            interfaceID == 0xf74b340a; // IPaymentPolicy
    }
}
