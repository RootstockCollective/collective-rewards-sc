import { expect } from "chai";
import hre from "hardhat";
import { Foo } from "../typechain-types";

describe("Foo contract", function () {
  describe("method id", function () {
    let foo: Foo;

    beforeEach(async function () {
      const fooFactory = await hre.ethers.getContractFactory("Foo");
      foo = await fooFactory.deploy();
    });

    it("should return value from paremeter", async function () {
      const x = 41;

      expect(await foo.id(x)).to.equal(x, "value mismatch");
    });
  });
});
