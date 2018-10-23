# ReserveBank
* Every client can receive EtherDollar loans from Reserve Bank by making a deposit of at least 1.5 times the size of their requested loan as collateral.
* The loans with collaterals that are worth less than 1.5 times the value of the loan due to Ether market prices will be liquidated<sup>[1](#footnote1)</sup>.<sup>[2](#footnote2)</sup>
* Every time the price of Reserve Bank Dollar is less than 1 EtherDollar, in addition to the loans with collaterals worth less than 1.5 times the value of the loan, other loans with the lowest amount of collateral will also be liquidated. 
* There is no obligation or time limit to settle the loans in Reserve Bank. Clients can settle their loans whenever they intend to unless liquidation is applicable for them.
* Reserve Bank’s design intends to maximize the collaterals deposited by loan receivers<sup>[3](#footnote3)</sup>. 
* The most significant risk for the money issued by EtherBanks is their collateral losing value to the extent that it is worth less than the loan. Maximizing the amount of collateral for receiving loans in Reserve Bank will highly reduce that risk.
* The approach in Reserve Bank in providing its limited loans to users who offer the largest amount of collateral results into Reserve Bank Dollars being the most risk free tokens comparing to tokens created in other EtherBanks.
# Interest Bank
* Every client can receive EtherDollar loans from Interest Bank by making a deposit of at least 1.5 times the size of their requested loan as collateral. 
* The loans with collaterals that are worth less than 1.5 times the value of the loan due to Ether market prices will be liquidated
* The loans in Interest Bank have an interest that is determined by the loan receivers when they request a loan. This interest can be increased or decreased anytime at their demand.
* Every time the price of Interest Bank Dollars is less than 1 EtherDollar,  in addition to the loans with collaterals worth less than 1.5 times the value of the loan, other loans with the lowest interest will also be liquidated. 
* There is no obligation or time limit to settle the loans in Interest Bank. Clients can settle their loans whenever they intend to unless liquidation is applicable for them.
* The interest paid by loan receivers will be distributed among those who hold Interest Bank Dollars.
* Interest Bank’s design intends to maximize the amount of paid interest for the Interest Bank Dollar holders. This approach motivates more people to hold tokens and expands the market for Interest Bank Dollars.
# Auto-Interest Bank
* Every client can receive EtherDollar loans from Auto-Interest Bank by making a deposit of at least 1.5 times the size of their requested loan as collateral. 
* The loans with collaterals that are worth less than 1.5 times the value of the loan due to Ether market prices will be liquidated
* The loans in Auto-Interest Bank have daily interest rates which we call DIR.
* DIR is assigned dynamically, daily and relative to price conditions of Auto-Interest Bank Dollars. Its lowest amount is zero.
* When the price for a Auto-Interest Bank Dollar is less than 1 EtherDollar, DIR will increase gradually and vice versa, when the price for Auto-Interest Bank Dollar is equal or higher than 1 EtherDollar, DIR will decrease gradually until it reaches zero. The pace in which DIR increases or decreases is relative to the difference in EtherDollar and Auto-Interest Bank Dollar prices.
* The interest that is assigned daily to the loans will be distributed among those who deposit their Auto-Interest Bank Dollars in Auto-Interest Bank in weekly, monthly, or annual periods. Depositing means locking the tokens in Auto-Interest Bank smart contract for a certain period of time.
* The longer the period of time clients lock their tokens, the bigger portion of the interest they receive from daily interests. Each day, those who deposit monthly will enjoy a larger amount of interest than those who deposit weekly.
* Loan receivers are obliged to pay the interest that is assigned to their loan on a daily basis at least once a week. Otherwise, their loan will be liquidated.
* There is no obligation or time limit to settle the loans in Auto-Interest Bank. Clients can settle their loans whenever they intend to unless liquidation is applicable for them.
* DIR will be defined and paid in EtherDollar rather than Ether. This way, delays in paying the interest won’t increase or decrease their worth.
* At any point in time before the end of their deposit period, the depositors can receive all their share of the interest by performing a single transaction<sup>[4](#footnote4)</sup>.
* Auto-Interest Bank intends to use the interest to quickly and effectively balance the supply and demand for Auto-Interest Bank Dollars.
# Time-Based Bank
* Every client can receive EtherDollar loans from Time-Based Bank by making a deposit of at least 3 times the size of their requested loan as collateral. 
* The loans with collaterals that are worth less than 1.5 times the value of the loan due to Ether market prices will be liquidated
* The loans in Time-Based Bank will be paid with 1day or 1month settlement dues.
* Relative to the due time for settlement, the loans will have various daily interest rates or DIRs. The minimum DIR will be for 1day loans and the maximum DIR will be for loans which have 1 month settlement periods.
* The daily interest rate for loans with 1day settlement due is called the basic DIR. Other DIRs for loans with longer settlement dues will be calculated as multiplication of the basic DIR.  
* The basic DIR will be assigned dynamically relative to the price of Time-Based Bank Dollars in the market. The minimum basic DIR is zero.

<a name="footnote1">1)</a> <sup>Liquidation means that EtherBank puts the loan’s collateral for sale. This way everyone can settle the loan on behalf of the receiver and win a part of his collateral. In other words, everyone can buy loan receiver’s collaterals by paying EtherDollars. After the sale, the remaining of the collateral will be paid back to the loan receiver and the EtherDollars will be eliminated by EtherBank. Because the price for liquidation is determined in the market, those who buy a part of the collateral to settle the loan will benefit to some extend and those whose loans are settled by others will lose to some extend.
  
<a name="footnote2">2)</a> <sup>Due to volatility of Ether, loan receivers have to make deposits worth more than 1.5 times the amount of their loans and, add to their loan collateral in case Ether price decreases.

<a name="footnote3">3)</a> <sup>The loans in Reserve Bank are completely free and users pay no interest. There is also no time limitations for paying back the loan and users can settle their loans whenever they want to. The only requirement for receiving a loan is providing enough Ethers as collateral.
This approach will create a huge amount of demand from those who own Ether and can provide them as collateral to receive free loans. But the loans are limited in Reserve Bank, because, every time the demand for receiving free loans from Reserve Bank exceeds the demand for holding Reserve Bank Dollars, the price of Reserve Bank Dollars will fall below 1 EtherDollar in the market.
In these circumstances, in order to reduce its supply, Reserve Bank will forcibly settle the loans with the lowest amount of collateral by liquidating them. This will create a competition among loan receivers not to have lower amounts of collateral than others. This competition will increase the collateral needed for receiving loans to an extent where the demand for receiving loans reaches the demand for holding Reserve Bank Dollars.
Reserve Bank never prohibits loans with collaterals equal to or slightly higher than 1.5 times their amount. However, every time these loans have the lowest amount of collateral compared to others, and the price for Reserve Bank Dollars is less than 1 EtherDollar, they will be instantly liquidated with some loss for the loan receivers and some benefit for the settlers.

<sup><a name="footnote4">4)</a> <sup>In fact, Auto-Interest Bank can only pay the interest share of depositors up until a week before this transaction because some loan receivers might have not paid their 7 day interest yet and calculating the last 7 days will not be completed. 
