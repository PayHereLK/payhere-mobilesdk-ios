//
//  PHEnums.swift
//  payHereSDK
//
//  Created by Kamal Upasena on 1/23/20.
//  Copyright © 2020 PayHere. All rights reserved.
//

import Foundation


public enum PHCurrency : String{
    case LKR = "LKR"
    case USD = "USD"
    case GBP = "GBP"
    case EUR = "EUR"
    case AUD = "AUD"
}

/**
  Recurring Period (A number & a word separated by a space such as 2 Week, 1 Month, 6 Month, 1 Year, etc. Word can be ‘Week’, ‘Month’ or ‘Year’ in singular. Number can be any to define recurrent period with word.)
   ~~~
    PHRecurrenceTime.Week(`number of Weeks`)
    PHRecurrenceTime.Month(`number of Months`)
    PHRecurrenceTime.Year(`number of Year`)
   ~~~
 
 */
public enum PHRecurrenceTime{
    case Week(period : Int)
    case Month(period : Int)
    case Year(period : Int)
}


/**
 Duration to charge ('Forever' if there's no time limitation. Otherwise a Number & a word separated by a space as 1 Month, 1 Year, 3 Year, ect. Word can be ‘Week’, ‘Month’, ‘Year’. Number should be compatible with the word in recurrence.)
  ~~~
    PHDuration.Week(`number of Weeks`)
    PHDuration.Month(`number of Months`)
    PHDuration.Year(`number of Year`)
    PHDuration.Forver
  ~~~
*/
public enum PHDuration{
    case Week(duration : Int)
    case Month(duration : Int)
    case Year(duration : Int)
    case Forver
}

internal enum SelectedAPI{
    case PreApproval
    case Recurrence
    case CheckOut
    case Authorize
}
