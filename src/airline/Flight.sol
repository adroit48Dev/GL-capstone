// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import "@openzeppelin/contracts/access/Ownable.sol";
import "contracts/library/StringCompare.sol";
import "hardhat/console.sol";

contract Flight is Ownable {
    struct Seat {
        string seat_number;
        address passenger;
        uint256 price;
        string seat_type;
        bool is_booked;
        uint256 ticket_no;
    }

    enum FlightStatus {
        PRESALE,
        SALE,
        LANDED,
        CANCELLED
    }

    struct FlightDetail {
        address owner;
        string flight_number;
        uint256 departure_time;
        uint256 arrival_time;
        uint256 delayed_departure_time;
        uint8 duration;
        FlightStatus status;
    }

    FlightDetail _flight_detail;
    mapping(string => Seat[]) seats;
    string[] seat_types;
    string[] available_seats;

    modifier onlyFlightOwner() {
        require(
            tx.origin == _flight_detail.owner,
            "Only flight owner can perform this."
        );
        _;
    }

    constructor(address _owner, string memory _flight_no) {
        _flight_detail = FlightDetail({
            owner: _owner,
            flight_number: _flight_no,
            status: FlightStatus.PRESALE,
            departure_time: 0,
            arrival_time: 0,
            delayed_departure_time: 0,
            duration: 0
        });
    }

    function getFlightOwner() public view returns (address) {
        return _flight_detail.owner;
    }

    function addSeats(
        string memory _seat_type,
        string[] memory _seats,
        uint256 _price
    ) public onlyOwner onlyFlightOwner returns (bool) {
        require(
            _flight_detail.status == FlightStatus.PRESALE,
            "Cannot add seats for deployed flights."
        );
        require(_seats.length > 0, "Invalid Seats");
        for (uint256 j = 0; j < _seats.length; j++) {
            seats[_seat_type].push(
                Seat({
                    seat_number: _seats[j],
                    passenger: address(0),
                    price: _price,
                    seat_type: _seat_type,
                    is_booked: false,
                    ticket_no: 0
                })
            );
            seat_types.push(_seat_type);
        }
        return true;
    }

    function deploy(uint256 _departure_time, uint256 _arrival_time)
        public
        onlyOwner
        onlyFlightOwner
        returns (bool)
    {
        require(seat_types.length != 0, "Flight doesn't have any seats.");
        require(
            _flight_detail.status == FlightStatus.PRESALE,
            "Flight cannot be re-deployed."
        );

        _flight_detail.departure_time = _departure_time;
        _flight_detail.arrival_time = _arrival_time;
        _flight_detail.status = FlightStatus.SALE;
        return true;
    }

    function getFlightStatusKeyByValue(FlightStatus _status)
        internal
        pure
        returns (string memory)
    {
        require(uint8(_status) <= 4, "Invalid key");
        if (FlightStatus.PRESALE == _status) return "Presale";
        if (FlightStatus.SALE == _status) return "Sale";
        if (FlightStatus.LANDED == _status) return "Landed";
        if (FlightStatus.CANCELLED == _status) return "Cancelled";
        return "";
    }

    function __isAvailableForBooking() private view returns (bool) {
        if (_flight_detail.status != FlightStatus.SALE) {
            return false;
        }

        return (block.timestamp < (__getDepartureTime() - 2 hours));
    }

    function __getDepartureTime() private view returns (uint256) {
        if (_flight_detail.delayed_departure_time != 0) {
            return _flight_detail.delayed_departure_time;
        }
        return _flight_detail.departure_time;
    }

    function noOfHoursBeforeDeparture() public view returns (uint256) {
        uint256 diff = (__getDepartureTime() - block.timestamp);
        return diff / 60 / 60;
    }

    function noOfHoursAfterDeparture() public view returns (uint256) {
        uint256 diff = (block.timestamp - __getDepartureTime());
        return diff / 60 / 60;
    }

    function isFlightTookOf() public view returns (bool) {
        int256 diff = (int256(__getDepartureTime()) - int256(block.timestamp));
        return diff < 0;
    }

    function land() public onlyOwner onlyFlightOwner returns (bool) {
        require(
            _flight_detail.status == FlightStatus.SALE,
            "Flight is not in state to be landed"
        );
        _flight_detail.status = FlightStatus.LANDED;
        return true;
    }

    function bookSeat(
        string memory _seat_type,
        string memory _seat_no,
        uint256 _ticket_no
    ) public returns (bool) {
        // require(__isAvailableForBooking(), "Flight is not available for booking.");
        require(
            __isSeatAvailable(_seat_type, _seat_no),
            "Seat is already booked."
        );

        for (uint256 j = 0; j < seats[_seat_type].length; j++) {
            if (
                StringCompare.isStringEqual(
                    seats[_seat_type][j].seat_number,
                    _seat_no
                )
            ) {
                seats[_seat_type][j].is_booked = true;
                seats[_seat_type][j].ticket_no = _ticket_no;
                return true;
            }
        }
        return false;
    }

    function releaseSeat(string memory _seat_type, string memory _seat_no)
        public
        returns (bool)
    {
        for (uint256 j = 0; j < seats[_seat_type].length; j++) {
            if (
                StringCompare.isStringEqual(
                    seats[_seat_type][j].seat_number,
                    _seat_no
                )
            ) {
                seats[_seat_type][j].is_booked = false;
                seats[_seat_type][j].ticket_no = 0;
                return true;
            }
        }
        return false;
    }

    function getSeatPrice(string memory _seat_type, string memory _seat_no)
        public
        view
        returns (uint256)
    {
        for (uint256 j = 0; j < seats[_seat_type].length; j++) {
            if (
                StringCompare.isStringEqual(
                    seats[_seat_type][j].seat_number,
                    _seat_no
                )
            ) {
                return seats[_seat_type][j].price;
            }
        }
        return 0;
    }

    function getFlightNo() public view returns (string memory) {
        return _flight_detail.flight_number;
    }

    function getAvailableSeats(string memory _seat_type)
        public
        returns (string[] memory)
    {
        require(__isAvailableForBooking(), "No seats available.");

        delete available_seats;
        for (uint256 j = 0; j < seats[_seat_type].length; j++) {
            if (!seats[_seat_type][j].is_booked) {
                available_seats.push(seats[_seat_type][j].seat_number);
            }
        }
        return available_seats;
    }

    function __isSeatAvailable(string memory _seat_type, string memory _seat_no)
        private
        view
        returns (bool)
    {
        for (uint256 j = 0; j < seats[_seat_type].length; j++) {
            if (
                StringCompare.isStringEqual(
                    seats[_seat_type][j].seat_number,
                    _seat_no
                ) && !seats[_seat_type][j].is_booked
            ) {
                return true;
            }
        }
        return false;
    }

    function isCancellable() public view returns (bool) {
        return
            _flight_detail.status == FlightStatus.SALE ||
            _flight_detail.status == FlightStatus.PRESALE;
    }

    function cancel() public onlyOwner {
        string memory status = getFlightStatusKeyByValue(_flight_detail.status);
        require(
            isCancellable(),
            string.concat(
                "Flight cannot be cancelled, as it is in ",
                status,
                " state."
            )
        );
        _flight_detail.status = FlightStatus.CANCELLED;
    }
}
