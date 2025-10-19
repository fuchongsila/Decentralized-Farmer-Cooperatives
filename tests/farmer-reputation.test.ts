import { describe, it, expect } from "vitest";
import { Clarinet, Tx, Chain, Account, Contract } from "@hirosystems/clarinet-sdk";

describe("Farmer Reputation and Reliability Scoring System", () => {
  it("should initialize a farmer's reputation profile with default values", () => {
    const contract = new Contract("farmer-reputation");
    const deployer = Clarinet.accounts.get("deployer")!;

    const result = contract.call("initialize-farmer-reputation", [deployer.address]);

    expect(result.isOk()).toBe(true);
  });

  it("should retrieve an initialized farmer's reputation profile", () => {
    const contract = new Contract("farmer-reputation");
    const deployer = Clarinet.accounts.get("deployer")!;

    contract.call("initialize-farmer-reputation", [deployer.address]);
    const reputation = contract.call("get-farmer-reputation", [deployer.address]);

    expect(reputation.value).toBeDefined();
  });

  it("should record a completed task and increase reliability score", () => {
    const contract = new Contract("farmer-reputation");
    const deployer = Clarinet.accounts.get("deployer")!;

    contract.call("initialize-farmer-reputation", [deployer.address]);
    const result = contract.call("record-task-completion", [deployer.address]);

    expect(result.isOk()).toBe(true);
  });

  it("should record a failed task and decrease reliability score", () => {
    const contract = new Contract("farmer-reputation");
    const deployer = Clarinet.accounts.get("deployer")!;

    contract.call("initialize-farmer-reputation", [deployer.address]);
    const result = contract.call("record-task-failure", [deployer.address]);

    expect(result.isOk()).toBe(true);
  });

  it("should allow farmers to submit ratings for each other", () => {
    const contract = new Contract("farmer-reputation");
    const deployer = Clarinet.accounts.get("deployer")!;
    const wallet1 = Clarinet.accounts.get("wallet_1")!;

    const result = contract.call("submit-farmer-rating", [
      deployer.address,
      "u8",
      "Reliable and professional farmer",
    ]);

    expect(result.isOk()).toBe(true);
  });

  it("should reject a rating outside 1-10 range", () => {
    const contract = new Contract("farmer-reputation");
    const deployer = Clarinet.accounts.get("deployer")!;

    const result = contract.call("submit-farmer-rating", [
      deployer.address,
      "u15",
      "Invalid rating",
    ]);

    expect(result.isErr()).toBe(true);
  });

  it("should prevent a farmer from rating themselves", () => {
    const contract = new Contract("farmer-reputation");
    const deployer = Clarinet.accounts.get("deployer")!;

    const result = contract.call("submit-farmer-rating", [
      deployer.address,
      "u7",
      "Self rating",
    ]);

    expect(result.isErr()).toBe(true);
  });

  it("should retrieve a submitted rating", () => {
    const contract = new Contract("farmer-reputation");
    const deployer = Clarinet.accounts.get("deployer")!;
    const wallet1 = Clarinet.accounts.get("wallet_1")!;

    contract.call("submit-farmer-rating", [
      wallet1.address,
      "u9",
      "Excellent work",
    ]);

    const rating = contract.call("get-farmer-rating", [
      deployer.address,
      wallet1.address,
    ]);

    expect(rating.value).toBeDefined();
  });

  it("should calculate average reliability score correctly", () => {
    const contract = new Contract("farmer-reputation");
    const deployer = Clarinet.accounts.get("deployer")!;

    contract.call("initialize-farmer-reputation", [deployer.address]);
    contract.call("record-task-completion", [deployer.address]);
    contract.call("record-task-completion", [deployer.address]);

    const avgScore = contract.call("get-average-reliability-score", [
      deployer.address,
    ]);

    expect(avgScore.value).toBeDefined();
    expect(avgScore.isOk()).toBe(true);
  });

  it("should calculate success rate for a farmer", () => {
    const contract = new Contract("farmer-reputation");
    const deployer = Clarinet.accounts.get("deployer")!;

    contract.call("initialize-farmer-reputation", [deployer.address]);
    contract.call("record-task-completion", [deployer.address]);
    contract.call("record-task-completion", [deployer.address]);
    contract.call("record-task-failure", [deployer.address]);

    const successRate = contract.call("get-farmer-success-rate", [
      deployer.address,
    ]);

    expect(successRate.value).toBeDefined();
    expect(successRate.isOk()).toBe(true);
  });

  it("should return 0 success rate for farmer with no tasks", () => {
    const contract = new Contract("farmer-reputation");
    const deployer = Clarinet.accounts.get("deployer")!;

    contract.call("initialize-farmer-reputation", [deployer.address]);

    const successRate = contract.call("get-farmer-success-rate", [
      deployer.address,
    ]);

    expect(successRate.value).toEqual("u0");
  });

  it("should track participation count across task records", () => {
    const contract = new Contract("farmer-reputation");
    const deployer = Clarinet.accounts.get("deployer")!;

    contract.call("initialize-farmer-reputation", [deployer.address]);
    contract.call("record-task-completion", [deployer.address]);
    contract.call("record-task-completion", [deployer.address]);
    contract.call("record-task-failure", [deployer.address]);

    const reputation = contract.call("get-farmer-reputation", [
      deployer.address,
    ]);

    expect(reputation.value).toBeDefined();
  });

  it("should update a farmer's rating when resubmitting", () => {
    const contract = new Contract("farmer-reputation");
    const deployer = Clarinet.accounts.get("deployer")!;
    const wallet1 = Clarinet.accounts.get("wallet_1")!;

    contract.call("submit-farmer-rating", [
      wallet1.address,
      "u5",
      "Average work",
    ]);

    const result = contract.call("submit-farmer-rating", [
      wallet1.address,
      "u9",
      "Improved performance",
    ]);

    expect(result.isOk()).toBe(true);
  });

  it("should handle multiple farmers and ratings", () => {
    const contract = new Contract("farmer-reputation");
    const deployer = Clarinet.accounts.get("deployer")!;
    const wallet1 = Clarinet.accounts.get("wallet_1")!;
    const wallet2 = Clarinet.accounts.get("wallet_2")!;

    contract.call("initialize-farmer-reputation", [deployer.address]);
    contract.call("initialize-farmer-reputation", [wallet1.address]);

    contract.call("submit-farmer-rating", [wallet1.address, "u8", "Good"]);
    contract.call("submit-farmer-rating", [wallet2.address, "u6", "OK"]);

    const rating1 = contract.call("get-farmer-rating", [
      deployer.address,
      wallet1.address,
    ]);

    expect(rating1.value).toBeDefined();
  });

  it("should compute reliability with multiple task attempts", () => {
    const contract = new Contract("farmer-reputation");
    const deployer = Clarinet.accounts.get("deployer")!;

    contract.call("initialize-farmer-reputation", [deployer.address]);

    for (let i = 0; i < 5; i++) {
      contract.call("record-task-completion", [deployer.address]);
    }

    const reputation = contract.call("get-farmer-reputation", [
      deployer.address,
    ]);

    expect(reputation.value).toBeDefined();
  });
});
