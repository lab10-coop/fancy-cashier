pragma solidity >=0.5.0 <0.6.0;

import "../../contracts/IPaymentPolicy.sol";

contract SimplePaymentPolicy is IPaymentPolicy {
    // accept everything >= 1, ignore who's sending it
    function isValidPayment(address, uint256 amount) external view returns(bool) {
        return amount >= 1E18;
    }

    // require the same amount of discount tokens for a 25% discount in payment tokens
    function getApplicableDiscount(address, uint256 paymentAmount) external view
        returns(uint256 neededDiscountTokenAmount, uint256 paymentTokenRefundAmount)
    {
        return (paymentAmount, paymentAmount / 4);
    }

    // ERC165 interface detection
    function supportsInterface(bytes4 interfaceID) external pure returns (bool) {
        return
        interfaceID == this.supportsInterface.selector || // ERC165
        interfaceID == 0xf74b340a; // IPaymentPolicy
    }
}
