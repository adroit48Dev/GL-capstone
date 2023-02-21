// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/escrow/Escrow.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "contracts/airline/Flight.sol";
import "contracts/library/AirlineFlight.sol";
import "contracts/airline/Ticket.sol";
import "hardhat/console.sol";

contract EagleAirlinesServer {
    using AirlineFlight for AvailableFlight;
    mapping(string => AvailableFlight) _fligtList;

    modifier onlyAvailableFlight(string memory flight_no) {
        require(_fligtList[flight_no].exists(), "Flight doesn't exist.");
        _;
    }

    function addFlight(string memory _flight_no)
        public
        returns (string memory)
    {
        require(
            !_fligtList[_flight_no].exists(),
            "Flight with this number already exist, Please choose another number."
        );
        AvailableFlight storage flight = _fligtList[_flight_no];
        console.log("Creating new flight...");
        if (flight.insert(_flight_no)) {
            console.log("Flight created.");
            return (string.concat("Flight added: ", _flight_no));
        }
        console.log("Flight creation failed.");
        return (string.concat("Flight addition failed: ", _flight_no));
    }

    function addSeats(
        string memory _flight_no,
        string memory _seat_type,
        string[] memory _seats,
        uint256 _price
    ) public onlyAvailableFlight(_flight_no) returns (string memory) {
        AvailableFlight storage _flight = _fligtList[_flight_no];
        console.log("Adding seats to flight...");
        if (_flight.addSeats(_seat_type, _seats, _price)) {
            console.log("Seats successfully added.");
            return (string.concat("Seats added: ", _flight_no));
        }
        console.log("Seats addition failed.");
        return (string.concat("Seats addtion failed: ", _flight_no));
    }

    function initiateFlight(
        string memory _flight_no,
        uint256 _departure_time,
        uint256 _arrival_time
    ) public onlyAvailableFlight(_flight_no) returns (string memory) {
        require(
            _arrival_time < _departure_time,
            "Departure time cannot be before arival time."
        );
        AvailableFlight storage _flight = _fligtList[_flight_no];
        console.log("Deploying flight...");
        if (_flight.initiateFlight(_departure_time, _arrival_time)) {
            console.log("Flight deployed successfully");
            return (string.concat("Flight deployed: ", _flight_no));
        }
        console.log("Failed to deploy flight.");
        return (string.concat("Failed to deploy flight: ", _flight_no));
    }

    function cancelFlight(string memory _flight_no)
        public
        payable
        onlyAvailableFlight(_flight_no)
        returns (string memory)
    {
        AvailableFlight storage _flight = _fligtList[_flight_no];
        require(
            _flight.flight.getFlightOwner() == msg.sender,
            "Only Flight owner can perform this."
        );
        console.log("Cancelling flight...");
        if (_flight.cancelFlight()) {
            console.log("Processing payments...");
            __processFlightPayments(_flight_no);
            console.log("Flight cancelled successfully.");
            return (string.concat("Flight cancelled: ", _flight_no));
        }
        console.log("Failed to cancel flight.");
        return (string.concat("Failed to cancel flight: ", _flight_no));
    }

    function getAvailableSeats(
        string memory _flight_no,
        string memory _seat_type
    ) public onlyAvailableFlight(_flight_no) returns (string[] memory) {
        AvailableFlight storage _flight = _fligtList[_flight_no];
        return _flight.getAvailableSeats(_seat_type);
    }

    function bookTicket(
        string memory _flight_no,
        string memory _seat_type,
        string memory _seat_number
    ) public onlyAvailableFlight(_flight_no) returns (string memory) {
        AvailableFlight storage _flight = _fligtList[_flight_no];
        console.log("Booking flight ticket...");
        (bool success, uint256 ticket_no) = _flight.bookTicket(
            _seat_type,
            _seat_number
        );
        if (success) {
            console.log(
                string.concat(
                    "Ticket booked with number: ",
                    Strings.toString(ticket_no)
                )
            );
            return (
                string.concat(
                    "Ticket booked with number: ",
                    Strings.toString(ticket_no)
                )
            );
        }
        console.log("Failed to book ticket.");
        return (string.concat("Failed to book ticket: ", _flight_no));
    }

    function pay(string memory _flight_no, uint256 _ticket_no)
        public
        payable
        onlyAvailableFlight(_flight_no)
        returns (string memory)
    {
        AvailableFlight storage _flight = _fligtList[_flight_no];
        console.log(
            string.concat(
                "Paying for ticket flight ticket...",
                Strings.toString(_ticket_no)
            )
        );
        if (_flight.pay(_ticket_no)) {
            console.log(
                string.concat(
                    "Payment successfull: ",
                    Strings.toString(_ticket_no)
                )
            );
            return (
                string.concat(
                    "Payment successfull: ",
                    Strings.toString(_ticket_no)
                )
            );
        }
        console.log("Payment failed.");
        return (
            string.concat("Payment failed: ", Strings.toString(_ticket_no))
        );
    }

    function landFlight(string memory _flight_no)
        public
        onlyAvailableFlight(_flight_no)
        returns (string memory)
    {
        AvailableFlight storage _flight = _fligtList[_flight_no];
        console.log(
            string.concat("Completing journey of flight...", _flight_no)
        );

        if (_flight.land()) {
            __processFlightPayments(_flight_no);
            console.log("Flight landed successfully.");
            return (string.concat("Flight landed: ", _flight_no));
        }
        console.log("Status update failed.");
        return (string.concat("Status update failed: ", _flight_no));
    }

    function __processFlightPayments(string memory _flight_no) private {
        AvailableFlight storage _flight = _fligtList[_flight_no];
        console.log("Payment processing started...");
        for (uint256 j = 0; j < _flight.ticket_nos.length; j++) {
            Ticket ticket = _flight.ticket_list[_flight.ticket_nos[j]];
            console.log(
                string.concat(
                    "Payment processing for ticket...",
                    Strings.toString(ticket.getTicketNumber())
                )
            );
            __processTicketPayments(ticket);
        }
    }

    function __processTicketPayments(Ticket ticket) private {
        uint256 passenger_amount;
        uint256 flight_amount;
        string memory status = ticket.getTicketStatus();
        if (StringCompare.isStringEqual(status, "Cancelled")) {
            passenger_amount = ticket.getRefundAmount();
            flight_amount = ticket.getCancellationDeductionAmount();
        } else if (StringCompare.isStringEqual(status, "Complete")) {
            flight_amount = ticket.getBookingAmount();
        }

        if (passenger_amount > 0) {
            (bool holder_sent, ) = ticket.getTicketHolder().call{
                value: passenger_amount
            }("");
            require(holder_sent, "Could not refund to ticket owner.");
        }
        if (flight_amount > 0) {
            (bool flight_sent, ) = ticket.getFlightOwner().call{
                value: flight_amount
            }("");
            require(flight_sent, "Could not transfer to flight owner.");
        }
    }

    function cancelTicket(string memory _flight_no, uint256 _ticket_no)
        public
        onlyAvailableFlight(_flight_no)
        returns (string memory, string memory)
    {
        AvailableFlight storage _flight = _fligtList[_flight_no];
        require(
            _flight.flight.isCancellable(),
            "Tickets cannot be cancelled as flight is already departed."
        );
        require(_flight.ticketExists(_ticket_no), "Ticket doesn't exist.");

        Ticket ticket = _flight.ticket_list[_ticket_no];
        if (!_flight.flight.isFlightTookOf()) {
            bool success = _flight.cancelTicketBeforeTakeoff(_ticket_no);
            require(success, "Ticket cancellation failed.");
            __processTicketPayments(ticket);
            return ("Ticket cancelled: ", Strings.toString(_ticket_no));
        } else {
            uint256 noOfHoursAfterDeparture = _flight
                .flight
                .noOfHoursAfterDeparture();
            if (noOfHoursAfterDeparture >= 24) {
                if (_flight.cancelFlight()) {
                    __processFlightPayments(_flight_no);
                    console.log("Flight cancelled successfully.");
                    return ("Flight cancelled: ", _flight_no);
                }
                return (
                    "Ticket cancellation failed: ",
                    Strings.toString(_ticket_no)
                );
            } else {
                return (
                    "Cancellation Failed",
                    "Pleaes wait for 24 hours after departure to cancel the flight."
                );
            }
        }
    }
}
