// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/escrow/Escrow.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "hardhat/console.sol";

contract Ticket is Ownable {
    enum TicketStatus {
        BOOKED,
        PAID,
        CANCELLED,
        COMPLETED
    }
    uint256 randNonce = 0;

    uint8 public flag;

    struct TicketDetail {
        address ticket_holder;
        address flight_owner;
        uint256 ticket_no;
        TicketStatus status;
        string seat_type;
        string seat_no;
        uint256 bill_amount;
        uint256 booking_amount;
        uint256 refund_amount;
        uint256 cancellation_deduction;
    }
    TicketDetail _ticket;

    modifier onlyFlightOwner() {
        require(
            _ticket.flight_owner != msg.sender,
            "Only Flight owner can perform this action."
        );
        _;
    }

    constructor(
        address _owner,
        address _flight_owner,
        string memory _seat_type,
        string memory _seat_no,
        uint256 _bill_amount
    ) {
        randNonce++;
        _ticket = TicketDetail({
            ticket_holder: _owner,
            flight_owner: _flight_owner,
            ticket_no: uint256(
                keccak256(abi.encodePacked(block.timestamp, _owner, randNonce))
            ) % 100000,
            status: TicketStatus.BOOKED,
            seat_no: _seat_no,
            seat_type: _seat_type,
            booking_amount: 0,
            refund_amount: 0,
            cancellation_deduction: 0,
            bill_amount: _bill_amount
        });
        flag = 1;
    }

    function getTicketStatusKeyByValue(TicketStatus _status)
        internal
        pure
        returns (string memory)
    {
        require(uint8(_status) <= 4, "Invalid key");
        if (TicketStatus.BOOKED == _status) return "Booked";
        if (TicketStatus.PAID == _status) return "Paid";
        if (TicketStatus.CANCELLED == _status) return "Cancelled";
        if (TicketStatus.COMPLETED == _status) return "Complete";
        return "";
    }

    function getTicketStatus() public view returns (string memory) {
        return getTicketStatusKeyByValue(_ticket.status);
    }

    function getTicketNumber() public view returns (uint256) {
        return _ticket.ticket_no;
    }

    function getFlightOwner() public view returns (address) {
        return _ticket.flight_owner;
    }

    function getTicketHolder() public view returns (address) {
        return _ticket.ticket_holder;
    }

    function getRefundAmount() public view returns (uint256) {
        return _ticket.refund_amount;
    }

    function getCancellationDeductionAmount() public view returns (uint256) {
        return _ticket.cancellation_deduction;
    }

    function getSeatType() public view returns (string memory) {
        return _ticket.seat_type;
    }

    function getSeatNo() public view returns (string memory) {
        return _ticket.seat_no;
    }

    function getBookingAmount() public view returns (uint256) {
        return _ticket.booking_amount;
    }

    function pay(uint256 _amount) public payable onlyOwner returns (bool) {
        require(
            _ticket.status == TicketStatus.BOOKED,
            string.concat(
                "Ticket cannot be booked as it is in ",
                getTicketStatusKeyByValue(_ticket.status),
                " state"
            )
        );
        require(
            _ticket.bill_amount == _amount,
            string.concat(
                "Payment should be of ETH: ",
                Strings.toString(_ticket.bill_amount),
                " only"
            )
        );

        _ticket.booking_amount = _amount;
        _ticket.status = TicketStatus.PAID;
        return true;
    }

    function isCancellable() public view returns (bool) {
        return
            _ticket.status == TicketStatus.PAID ||
            _ticket.status == TicketStatus.BOOKED;
    }

    function cancel(uint256 _refund_percentage) public payable returns (bool) {
        require(
            _ticket.status == TicketStatus.PAID ||
                _ticket.status == TicketStatus.BOOKED,
            "Ticket cannot be cancelled."
        );

        console.log("Cancelling Ticket: ", Strings.toString(_ticket.ticket_no));
        console.log("Refund % : ", Strings.toString(_refund_percentage));
        if (_ticket.booking_amount > 0) {
            uint256 _refund_amount = SafeMath.div(
                SafeMath.mul(_ticket.booking_amount, _refund_percentage),
                100
            );
            console.log("Refund Amount : ", Strings.toString(_refund_amount));
            _ticket.refund_amount = _refund_amount;
            _ticket.cancellation_deduction = SafeMath.sub(
                _ticket.booking_amount,
                _refund_amount
            );
            console.log(
                "Cancellation Deduction Amount : ",
                Strings.toString(_ticket.cancellation_deduction)
            );
            _ticket.status = TicketStatus.CANCELLED;
            console.log(
                "Ticket cancelled: ",
                Strings.toString(_ticket.ticket_no)
            );
            return true;
        }
        return true;
    }

    function journeyComplete() public onlyFlightOwner returns (string memory) {
        require(
            _ticket.status == TicketStatus.PAID,
            "Ticket not in right state to complete."
        );

        console.log(
            "Updating Ticket to complete journey: ",
            Strings.toString(_ticket.ticket_no)
        );
        _ticket.status = TicketStatus.COMPLETED;
        console.log("Ticket closed: ", Strings.toString(_ticket.ticket_no));
        return "Ticket is closed.";
    }
}
