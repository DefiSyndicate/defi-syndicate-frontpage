pragma solidity ^0.6.12;
import "./JoePair.sol";

contract CalHash {
    function getInitHash() public pure returns(bytes32){
        bytes memory bytecode = type(JoePair).creationCode;
        return keccak256(abi.encodePacked(bytecode));
    }
}