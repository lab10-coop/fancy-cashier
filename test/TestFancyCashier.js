const FancyCashier = artifacts.require("FancyCashier");
const ERC20Contract = artifacts.require("MinimalERC20");
const ERC677Contract = artifacts.require("MinimalERC677");
const SimplePaymentPolicy = artifacts.require("SimplePaymentPolicy");
const Lab10DrinksPaymentPolicy = artifacts.require("Lab10DrinksPaymentPolicy");
const utils = require("./utils");

contract("FancyCashier", accounts => {
    const draghi = accounts[0]; // random guy emitting money - default owner of the contract
    const bezos = accounts[1]; // random guy selling stuff
    const payer1 = accounts[2]; // random guy getting rid of money
    const nirvana = accounts[9];

    let fancyCashier;
    let paymentToken;
    let discountToken;
    let paymentPolicy;

    describe("privileged methods", function() {
        beforeEach(async () => {
            // let draghi do some printing...
            paymentToken = await ERC677Contract.new(web3.utils.toWei("100000"), "Payment Token", 18, "PAY");
            discountToken = await ERC20Contract.new(web3.utils.toWei("100000"), "Discount Token", 18, "DSC");
            paymentPolicy = await SimplePaymentPolicy.new();

            // initialize the cashier contract
            fancyCashier = await FancyCashier.new(paymentToken.address, discountToken.address, paymentPolicy.address);

            // provide the contract with payment tokens and discount tokens
            await paymentToken.transfer(fancyCashier.address, web3.utils.toWei("1000"));
            await discountToken.transfer(fancyCashier.address, web3.utils.toWei("1000"));
        });

        it("only owner can change owner", async() => {
            utils.assertRevert(fancyCashier.setOwner(bezos, { from: bezos }));
            await fancyCashier.setOwner(bezos);
        });

        it("only owner can withdraw payment tokens", async() => {
            utils.assertRevert(fancyCashier.withdrawPaymentTokens(bezos, web3.utils.toWei("1"), { from: bezos }));
            await fancyCashier.withdrawPaymentTokens(bezos, web3.utils.toWei("1"));
            assert.strictEqual((await paymentToken.balanceOf(bezos)).toString(), web3.utils.toWei("1"));
        });

        it("withdraw all payment tokens", async() => {
            // first setting a new owner in order to start with a balance of zero
            await fancyCashier.setOwner(bezos);
            await fancyCashier.withdrawPaymentTokens(bezos, web3.utils.toWei("1000"), { from: bezos });
            assert.strictEqual((await paymentToken.balanceOf(bezos)).toString(), web3.utils.toWei("1000"));
            assert.strictEqual((await paymentToken.balanceOf(fancyCashier.address)).toString(), "0");
        });

        it("only owner can withdraw discount tokens", async() => {
            // custom receiver, amount
            utils.assertRevert(fancyCashier.withdrawDiscountTokens(bezos, web3.utils.toWei("1"), { from: bezos }));
            await fancyCashier.withdrawDiscountTokens(bezos, web3.utils.toWei("1"));
            assert.strictEqual((await discountToken.balanceOf(bezos)).toString(), web3.utils.toWei("1"));
        });

        it("withdraw all discount tokens", async() => {
            // first setting a new owner in order to start with a balance of zero
            await fancyCashier.setOwner(bezos);
            await fancyCashier.withdrawDiscountTokens(bezos, web3.utils.toWei("1000"), { from: bezos });
            assert.strictEqual((await discountToken.balanceOf(bezos)).toString(), web3.utils.toWei("1000"));
            assert.strictEqual((await discountToken.balanceOf(fancyCashier.address)).toString(), "0");
        });

        it("withdraw other (alien) tokens", async() => {
            alienToken = await ERC20Contract.new(web3.utils.toWei("100000"), "Alien Token", 18, "ALT");
            // provide the contract with some of them
            await alienToken.transfer(fancyCashier.address, web3.utils.toWei("1000"));

            // first setting a new owner in order to start with a balance of zero
            await fancyCashier.setOwner(bezos);
            await fancyCashier.withdrawAlienTokens(alienToken.address, bezos, { from: bezos });
            assert.strictEqual((await alienToken.balanceOf(bezos)).toString(), web3.utils.toWei("1000"));
        });


        it("only owner can set new payment token", async() => {
            const newPaymentToken = await ERC677Contract.new(web3.utils.toWei("100000"), "New Payment Token", 18, "NPAY");

            utils.assertRevert(fancyCashier.setPaymentToken(newPaymentToken.address, { from: bezos }));
            await fancyCashier.setPaymentToken(newPaymentToken.address);
        });

        it("only owner can set new discount token", async() => {
            const newDiscountToken = await ERC677Contract.new(web3.utils.toWei("100000"), "New Discount Token", 18, "NDSC");

            utils.assertRevert(fancyCashier.setDiscountToken(newDiscountToken.address, { from: bezos }));
            await fancyCashier.setDiscountToken(newDiscountToken.address);
        });
        it("only owner can set new payment policy", async() => {
            const newPaymentPolicy = await Lab10DrinksPaymentPolicy.new();

            utils.assertRevert(fancyCashier.setPaymentPolicy(newPaymentPolicy.address, { from: bezos }));
            await fancyCashier.setPaymentPolicy(newPaymentPolicy.address);
        });
    });

    describe("payments with simple policy", function() {
        beforeEach(async () => {
            // let draghi do some printing...
            paymentToken = await ERC677Contract.new(web3.utils.toWei("100000"), "Payment Token", 18, "PAY");
            discountToken = await ERC20Contract.new(web3.utils.toWei("100000"), "Discount Token", 18, "DSC");
            paymentPolicy = await SimplePaymentPolicy.new();
            await paymentToken.transfer(payer1, web3.utils.toWei("1000"));
            await discountToken.transfer(payer1, web3.utils.toWei("1000"));

            // initialize the cashier contract
            fancyCashier = await FancyCashier.new(paymentToken.address, discountToken.address, paymentPolicy.address);
        });

        it("pay without discount (no discount tokens, no allowance)", async() => {
            await paymentToken.transfer(fancyCashier.address, web3.utils.toWei("4"), { from: payer1 });

            const cashierBalance = await paymentToken.balanceOf(fancyCashier.address);
            assert.strictEqual(cashierBalance.toString(), web3.utils.toWei("4"));
        });

        it("pay with discount", async() => {
            // allow cashier to use discount tokens
            await discountToken.approve(fancyCashier.address, web3.utils.toWei("100"), { from: payer1 });

            await paymentToken.transfer(fancyCashier.address, web3.utils.toWei("8"), { from: payer1 });

            const cashierPTBalance = await paymentToken.balanceOf(fancyCashier.address);
            const cashierDTBalance = await discountToken.balanceOf(fancyCashier.address);
            assert.strictEqual(cashierPTBalance.toString(), web3.utils.toWei("6"));
            assert.strictEqual(cashierDTBalance.toString(), web3.utils.toWei("8"));
        });

        it("pay without discount (insufficient allowance)", async() => {
            // allow cashier to use discount tokens
            await discountToken.approve(fancyCashier.address, web3.utils.toWei("1"), { from: payer1 });

            // the actual payment
            await paymentToken.transfer(fancyCashier.address, web3.utils.toWei("8"), { from: payer1 });

            const cashierPTBalance = await paymentToken.balanceOf(fancyCashier.address);
            const cashierDTBalance = await discountToken.balanceOf(fancyCashier.address);
            assert.strictEqual(cashierPTBalance.toString(), web3.utils.toWei("8"));
            assert.strictEqual(cashierDTBalance.toString(), web3.utils.toWei("0"));
        });

        it("pay without discount (insufficient discount tokens)", async() => {
            // get rid of all but 1 discount token
            await discountToken.transfer(nirvana, web3.utils.toWei("999"), { from: payer1 });

            // allow cashier to use discount tokens
            await discountToken.approve(fancyCashier.address, web3.utils.toWei("100"), { from: payer1 });

            // the actual payment
            await paymentToken.transfer(fancyCashier.address, web3.utils.toWei("8"), { from: payer1 });

            const cashierPTBalance = await paymentToken.balanceOf(fancyCashier.address);
            const cashierDTBalance = await discountToken.balanceOf(fancyCashier.address);
            assert.strictEqual(cashierPTBalance.toString(), web3.utils.toWei("8"));
            assert.strictEqual(cashierDTBalance.toString(), web3.utils.toWei("0"));
        });
    });

    describe("payments with lab10 drinks policy", function() {
        beforeEach(async () => {
            // let draghi do some printing...
            paymentToken = await ERC677Contract.new(web3.utils.toWei("100000"), "Payment Token", 18, "PAY");
            discountToken = await ERC20Contract.new(web3.utils.toWei("100000"), "Discount Token", 18, "DSC");
            paymentPolicy = await Lab10DrinksPaymentPolicy.new();
            await paymentToken.transfer(payer1, web3.utils.toWei("1000"));
            await discountToken.transfer(payer1, web3.utils.toWei("1000"));

            // initialize the cashier contract
            fancyCashier = await FancyCashier.new(paymentToken.address, discountToken.address, paymentPolicy.address);
        });

        it("reject if amount too low", async() => {
            // assumption: transferAndCall throws an exception if the receive hook fails
            utils.assertRevert(paymentToken.transferAndCall(fancyCashier.address, web3.utils.toWei("1"), { from: payer1 }));
        });

        it("pay without discount (no discount tokens, no allowance)", async() => {
            await paymentToken.transfer(fancyCashier.address, web3.utils.toWei("3"), { from: payer1 });

            const cashierBalance = await paymentToken.balanceOf(fancyCashier.address);
            assert.strictEqual(cashierBalance.toString(), web3.utils.toWei("3"));
        });

        it("pay with discount", async() => {
            // allow cashier to use discount tokens
            await discountToken.approve(fancyCashier.address, web3.utils.toWei("100"), { from: payer1 });

            await paymentToken.transfer(fancyCashier.address, web3.utils.toWei("3"), { from: payer1 });

            const cashierPTBalance = await paymentToken.balanceOf(fancyCashier.address);
            const cashierDTBalance = await discountToken.balanceOf(fancyCashier.address);
            assert.strictEqual(cashierPTBalance.toString(), web3.utils.toWei("2"));
            assert.strictEqual(cashierDTBalance.toString(), web3.utils.toWei("2"));
        });
    });
});
