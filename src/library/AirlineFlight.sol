// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import "contracts/airline/Flight.sol";
import "contracts/airline/Ticket.sol";

struct AvailableFlight {
    Flight flight;
    bool flag;
    mapping(uint256 => Ticket) ticket_list;
    uint256[] ticket_nos;
}

library AirlineFlight {
    function exists(AvailableFlight storage self) public view returns (bool) {
        return self.flag;
    }

    function ticketExists(AvailableFlight storage self, uint256 ticket_no)
        public
        view
        returns (bool)
    {
        for (uint256 j = 0; j < self.ticket_nos.length; j++) {
            if (self.ticket_nos[j] == ticket_no) {
                return true;
            }
        }
        return false;
    }

    function insert(AvailableFlight storage self, string memory _flight_no)
        public
        returns (bool)
    {
        self.flight = new Flight(tx.origin, _flight_no);
        self.flag = true;
        return true;
    }

    function addSeats(
        AvailableFlight storage self,
        string memory _seat_type,
        string[] memory _seats,
        uint256 _price
    ) public returns (bool) {
        return self.flight.addSeats(_seat_type, _seats, _price);
    }

    function initiateFlight(
        AvailableFlight storage self,
        uint256 _departure_time,
        uint256 _arrival_time
    ) public returns (bool) {
        return self.flight.deploy(_departure_time, _arrival_time);
    }

    function cancelFlight(AvailableFlight storage self) public returns (bool) {
        self.flight.cancel();
        console.log(
            string.concat(
                "Total tickets: ",
                Strings.toString(self.ticket_nos.length)
            )
        );
        for (uint256 j = 0; j < self.ticket_nos.length; j++) {
            Ticket ticket = self.ticket_list[self.ticket_nos[j]];
            ticket.cancel(100);
        }
        return true;
    }

    function getAvailableSeats(
        AvailableFlight storage self,
        string memory _seat_type
    ) public returns (string[] memory) {
        return self.flight.getAvailableSeats(_seat_type);
    }

    function bookTicket(
        AvailableFlight storage self,
        string memory _seat_type,
        string memory _seat_number
    ) public returns (bool, uint256) {
        uint256 price = self.flight.getSeatPrice(_seat_type, _seat_number);
        Ticket ticket = new Ticket(
            tx.origin,
            self.flight.getFlightOwner(),
            _seat_type,
            _seat_number,
            price
        );
        bool success = self.flight.bookSeat(
            _seat_type,
            _seat_number,
            ticket.getTicketNumber()
        );
        if (success) {
            self.ticket_list[ticket.getTicketNumber()] = ticket;
            self.ticket_nos.push(ticket.getTicketNumber());
            return (true, ticket.getTicketNumber());
        }
        delete ticket;
        return (false, 0);
    }

    function pay(AvailableFlight storage self, uint256 _ticket_no)
        public
        returns (bool)
    {
        Ticket ticket = self.ticket_list[_ticket_no];
        return ticket.pay(msg.value);
    }

    function land(AvailableFlight storage self) public returns (bool) {
        if (self.flight.land()) {
            for (uint256 j = 0; j < self.ticket_nos.length; j++) {
                Ticket ticket = self.ticket_list[self.ticket_nos[j]];
                ticket.journeyComplete();
            }
            return true;
        }
        return false;
    }

    function cancelTicketBeforeTakeoff(
        AvailableFlight storage self,
        uint256 _ticket_no
    ) public returns (bool) {
        uint256 noOfHoursBeforeDeparture = self
            .flight
            .noOfHoursBeforeDeparture();

        console.log(
            string.concat(
                "hours before depart.",
                Strings.toString(noOfHoursBeforeDeparture)
            )
        );
        uint256 percentageRefund = 0;
        if (noOfHoursBeforeDeparture >= 24 * 7) {
            percentageRefund = 70;
        } else if (noOfHoursBeforeDeparture >= 24 * 4) {
            percentageRefund = 50;
        } else if (noOfHoursBeforeDeparture >= 2) {
            percentageRefund = 30;
        }
        console.log(
            string.concat("%refund: ", Strings.toString(percentageRefund))
        );

        Ticket ticket = self.ticket_list[_ticket_no];
        bool flight_flag = self.flight.releaseSeat(
            ticket.getSeatType(),
            ticket.getSeatNo()
        );
        bool ticket_flag = ticket.cancel(percentageRefund);
        bool success = flight_flag && ticket_flag;
        if (success) {
            for (uint256 j = 0; j < self.ticket_nos.length; j++) {
                if (self.ticket_nos[j] == _ticket_no) {
                    console.log(
                        string.concat(
                            "Deleting ticket",
                            Strings.toString(_ticket_no)
                        )
                    );
                    delete self.ticket_list[self.ticket_nos[j]];
                    delete self.ticket_nos[j];
                    self.ticket_nos[j] = self.ticket_nos[
                        self.ticket_nos.length - 1
                    ];
                    self.ticket_nos.pop();
                    return success;
                }
            }
        }
        return false;
    }
}
