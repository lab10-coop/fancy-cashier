pragma solidity >=0.5.0 <0.6.0;

// ERC165 interface id: 0xf74b340a
// contracts implementing this interface also must implement the ERC165 interface
interface IPaymentPolicy {
    function isValidPayment(address payer, uint256 amount) external view returns(bool);
    function getApplicableDiscount(address payer, uint256 paymentAmount) external view
        returns(uint256 neededDiscountTokenAmount, uint256 paymentTokenRefundAmount);
}
