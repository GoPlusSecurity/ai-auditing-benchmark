// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface TimeHelper {
    struct _DateTime {
        uint year;
        uint month;
        uint day;
        uint hour;
        uint minute;
        uint second;
        uint weekday;
    }
    function getYearMonthDay(
        uint _timestamp,
        uint _adjustHour
    )
        external
        view
        returns (
            _DateTime memory dt,
            uint day,
            uint second,
            uint zeroTime,
            string memory date,
            string memory time
        );
}
