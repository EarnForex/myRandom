//+------------------------------------------------------------------+
//|                                                     myRandom.mq5 |
//|                             Copyright © 2007-2022, EarnForex.com |
//|                                       https://www.earnforex.com/ |
//+------------------------------------------------------------------+
#property copyright "Copyright © 2007-2022, EarnForex"
#property link      "https://www.earnforex.com/metatrader-expert-advisors/myRandom/"
#property version   "1.03"

#property description "myRandom - places a trade in random direction."
#property description "You can control stop-loss, take-profit, volume, and entry period."

#include <Trade/Trade.mqh>

input group "Main"
input int RandomEntryPeriod = 1; //RandomEntryPeriod: How many bars to wait before entering a new position?
input int StopLoss = 1200;
input int TakeProfit = 600;
input group "Money management"
input double Lots = 0.1; // Lots - Position will be incremented with this volume
input group "Miscellaneous"
input int Slippage = 3;
input int Magic = 794823491;
input string Commentary = "myRandom";

// Global variables:
int LastBars = 0;
int OrderTaken = 0;
ENUM_SYMBOL_TRADE_EXECUTION Execution_Mode;
double Poin;
int Deviation;

// Main trading object:
CTrade *Trade;

void OnInit()
{
    // Checking for unconventional Point digits number.
    if ((_Point == 0.00001) || (_Point == 0.001))
    {
        Poin = _Point * 10;
        Deviation = Slippage * 10;
    }
    else
    {
        Poin = _Point; // Normal
        Deviation = Slippage;
    }

    Trade = new CTrade;
    Trade.SetDeviationInPoints(Deviation);
    Trade.SetExpertMagicNumber(Magic);
}

void OnDeinit(const int reason)
{
    delete Trade;
}

void OnTick()
{
    Execution_Mode = (ENUM_SYMBOL_TRADE_EXECUTION)SymbolInfoInteger(Symbol(), SYMBOL_TRADE_EXEMODE);
    
    if (Execution_Mode != SYMBOL_TRADE_EXECUTION_INSTANT) DoSLTP();

    if (LastBars == Bars(_Symbol, _Period)) return;
    else LastBars = Bars(_Symbol, _Period);

    if (Lots < SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN))
    {
        Print("Lots parameter < ", SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN), " minimum for ", _Symbol, ".");
        return;
    }

    
    if (AccountInfoInteger(ACCOUNT_MARGIN_MODE) == ACCOUNT_MARGIN_MODE_RETAIL_NETTING)
    {
        if (PositionSelect(_Symbol)) return; // Netting mode and the trade is on.
    }
    else if (AccountInfoInteger(ACCOUNT_MARGIN_MODE) == ACCOUNT_MARGIN_MODE_RETAIL_HEDGING)
    {
        for (int i = 0; i < PositionsTotal(); i++)
        {
            if (!PositionSelectByTicket(PositionGetTicket(i))) continue;
            if ((PositionGetString(POSITION_SYMBOL) == Symbol()) && (PositionGetInteger(POSITION_MAGIC) == Magic)) return; // The trade is on.
        }
    }

    MathSrand((int)TimeLocal());

    if (Bars(_Symbol, _Period) >= OrderTaken + RandomEntryPeriod)
    {
        if ((MathRand() % 2) == 1)
        {
            fSell();
        }
        else
        {
            fBuy();
        }
        OrderTaken = Bars(_Symbol, _Period);
    }
}

void fBuy()
{
    double SL = 0, TP = 0;
    double Ask = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
    if (Execution_Mode == SYMBOL_TRADE_EXECUTION_INSTANT)
    {
        if (StopLoss > 0) SL = NormalizeDouble(Ask - StopLoss * Poin, _Digits);
        if (TakeProfit > 0) TP = NormalizeDouble(Ask + TakeProfit * Poin, _Digits);
    }
    if (!Trade.PositionOpen(_Symbol, ORDER_TYPE_BUY, Lots, Ask, SL, TP, Commentary))
    {
        int e = GetLastError();
        Print("OrderSend Error: ", e);
    }
}

void fSell()
{
    double SL = 0, TP = 0;
    double Bid = SymbolInfoDouble(Symbol(), SYMBOL_BID);
    if (Execution_Mode == SYMBOL_TRADE_EXECUTION_INSTANT)
    {
        if (StopLoss > 0) SL = NormalizeDouble(Bid + StopLoss * Poin, _Digits);
        if (TakeProfit > 0) TP = NormalizeDouble(Bid - TakeProfit * Poin, _Digits);
    }
    if (!Trade.PositionOpen(_Symbol, ORDER_TYPE_SELL, Lots, Bid, SL, TP, Commentary))
    {
        int e = GetLastError();
        Print("OrderSend Error: ", e);
    }
}

// Applies SL and TP to open positions if ECN mode is on.
void DoSLTP()
{
    double SL = 0, TP = 0;

    for (int i = 0; i < PositionsTotal(); i++)
    {
        if (!PositionSelectByTicket(PositionGetTicket(i))) continue;
        if ((PositionGetString(POSITION_SYMBOL) != Symbol()) || (PositionGetInteger(POSITION_MAGIC) != Magic)) continue; // The trade is on.

        if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
        {
            if (StopLoss > 0) SL = NormalizeDouble(PositionGetDouble(POSITION_PRICE_OPEN) - StopLoss * Poin, _Digits);
            if (TakeProfit > 0) TP = NormalizeDouble(PositionGetDouble(POSITION_PRICE_OPEN) + TakeProfit * Poin, _Digits);
        }
        else if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
        {
            if (StopLoss > 0) SL = NormalizeDouble(PositionGetDouble(POSITION_PRICE_OPEN) + StopLoss * Poin, _Digits);
            if (TakeProfit > 0) TP = NormalizeDouble(PositionGetDouble(POSITION_PRICE_OPEN) - TakeProfit * Poin, _Digits);
        }

        if (((PositionGetDouble(POSITION_SL) != SL) || (PositionGetDouble(POSITION_TP) != TP)) && (PositionGetDouble(POSITION_SL) == 0) && (PositionGetDouble(POSITION_TP) == 0))
        {
            if (!Trade.PositionModify(_Symbol, SL, TP))
            {
                int e = GetLastError();
                Print("OrderSend Error: ", e);
            }
        }
    }
}
//+------------------------------------------------------------------+