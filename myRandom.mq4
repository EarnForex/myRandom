//+------------------------------------------------------------------+
//|                                                     myRandom.mq4 |
//|                             Copyright © 2007-2022, EarnForex.com |
//|                                       https://www.earnforex.com/ |
//+------------------------------------------------------------------+
#property copyright "Copyright © 2007-2022, EarnForex"
#property link      "https://www.earnforex.com/metatrader-expert-advisors/myRandom/"
#property version   "1.03"
#property strict

#property description "myRandom - places a trade in random direction."
#property description "You can control stop-loss, take-profit, volume, and entry period."

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
}

void OnTick()
{
    Execution_Mode = (ENUM_SYMBOL_TRADE_EXECUTION)SymbolInfoInteger(Symbol(), SYMBOL_TRADE_EXEMODE);
    
    if (Execution_Mode != SYMBOL_TRADE_EXECUTION_INSTANT) DoSLTP();

    if (LastBars == Bars) return;
    else LastBars = Bars;

    if (Lots < SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN))
    {
        Print("Lots parameter < ", SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN), " minimum for ", _Symbol, ".");
        return;
    }

    MathSrand((int)TimeLocal());

    int count = 0;
    int total = OrdersTotal();
    for (int pos = 0; pos < total; pos++)
    {
        if (OrderSelect(pos, SELECT_BY_POS) == false) continue;
        if ((OrderMagicNumber() == Magic) && (OrderSymbol() == Symbol())) return; // Don't open more than 1 trade.
    }

    if (Bars >= OrderTaken + RandomEntryPeriod)
    {
        if ((MathRand() % 2) == 1)
        {
            fSell();
        }
        else
        {
            fBuy();
        }
        OrderTaken = Bars;
    }
}

void fBuy()
{
    double SL = 0, TP = 0;
    RefreshRates();
    if (Execution_Mode == SYMBOL_TRADE_EXECUTION_INSTANT)
    {
        if (StopLoss > 0) SL = NormalizeDouble(Ask - StopLoss * Poin, _Digits);
        if (TakeProfit > 0) TP = NormalizeDouble(Ask + TakeProfit * Poin, _Digits);
    }
    int result = OrderSend(Symbol(), OP_BUY, Lots, Ask, Deviation, SL, TP, Commentary, Magic);
    if (result == -1)
    {
        int e = GetLastError();
        Print("OrderSend Error: ", e);
    }
}

void fSell()
{
    double SL = 0, TP = 0;
    RefreshRates();
    if (Execution_Mode == SYMBOL_TRADE_EXECUTION_INSTANT)
    {
        if (StopLoss > 0) SL = NormalizeDouble(Bid + StopLoss * Poin, _Digits);
        if (TakeProfit > 0) TP = NormalizeDouble(Bid - TakeProfit * Poin, _Digits);
    }
    int result = OrderSend(Symbol(), OP_SELL, Lots, Bid, Deviation, SL, TP, Commentary, Magic);
    if (result == -1)
    {
        int e = GetLastError();
        Print("OrderSend Error: ", e);
    }
}

// Applies SL and TP to open positions in ECN mode.
void DoSLTP()
{
    double SL = 0, TP = 0;
    for (int i = 0; i < OrdersTotal(); i++)
    {
        if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
        if ((OrderMagicNumber() == Magic) && (OrderSymbol() == Symbol()))
        {
            if (OrderType() == OP_BUY)
            {
                if (StopLoss > 0) SL = NormalizeDouble(OrderOpenPrice() - StopLoss * Poin, _Digits);
                if (TakeProfit > 0) TP = NormalizeDouble(OrderOpenPrice() + TakeProfit * Poin, _Digits);
                if (((OrderStopLoss() != SL) || (OrderTakeProfit() != TP)) && (OrderStopLoss() == 0) && (OrderTakeProfit() == 0))
                {
                    if (!OrderModify(OrderTicket(), OrderOpenPrice(), SL, TP, 0))
                    {
                        int e = GetLastError();
                        Print("OrderModify Error: ", e);
                    }
                }
            }
            else if (OrderType() == OP_SELL)
            {
                if (StopLoss > 0) SL = NormalizeDouble(OrderOpenPrice() + StopLoss * Poin, _Digits);
                if (TakeProfit > 0) TP = NormalizeDouble(OrderOpenPrice() - TakeProfit * Poin, _Digits);
                if (((OrderStopLoss() != SL) || (OrderTakeProfit() != TP)) && (OrderStopLoss() == 0) && (OrderTakeProfit() == 0))
                {
                    if (!OrderModify(OrderTicket(), OrderOpenPrice(), SL, TP, 0))
                    {
                        int e = GetLastError();
                        Print("OrderModify Error: ", e);
                    }
                }
            }
        }
    }
}
//+------------------------------------------------------------------+