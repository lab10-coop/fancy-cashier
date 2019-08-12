pragma solidity >=0.5.0 <0.6.0;

import "./MinimalERC20.sol";

contract MinimalERC677 is MinimalERC20 {
    event Transfer(address indexed from, address indexed to, uint value, bytes data);

    constructor(uint256 _initialAmount, string memory _tokenName, uint8 _decimalUnits, string memory _tokenSymbol)
        MinimalERC20(_initialAmount, _tokenName, _decimalUnits, _tokenSymbol)
        public { }

    // overridden ERC20 transfer method: try to invoke the callback if transferring to a contract
    function transfer(address _to, uint256 _value) public returns (bool) {
        //require(superTransfer(_to, _value));
        require(super.transfer(_to, _value));
        if (isContract(_to)) {
            // will fail silently if the receiver contract doesn't implement the callback function
            receiverContractCallback(_to, _value, new bytes(0));
        }
        return true;
    }

    // ERC677 specific transfer method: fails if the callback on the receiver fails (e.g. because not implemented)
    function transferAndCall(address _to, uint _value, bytes calldata _data) external returns (bool) {
        require(superTransfer(_to, _value));
        emit Transfer(msg.sender, _to, _value, _data);

        if (isContract(_to)) {
            require(receiverContractCallback(_to, _value, _data));
        }
        return true;
    }

    // for some reason invoking super.transfer() directly from the public methods fails
    function superTransfer(address _to, uint256 _value) internal returns(bool) {
        return super.transfer(_to, _value);
    }

    function receiverContractCallback(address _to, uint _value, bytes memory _data) private returns(bool) {
        (bool success,) = _to.call(abi.encodeWithSignature("onTokenTransfer(address,uint256,bytes)", msg.sender, _value, _data));
        return success;
    }

    function isContract(address _addr) private view returns (bool) {
        uint length;
        assembly { length := extcodesize(_addr) }
        return length > 0;
    }
}
