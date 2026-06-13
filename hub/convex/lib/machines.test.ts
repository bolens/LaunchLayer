import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { machineSummary, mergeMachineCandidates } from "./machines";
import { sampleFingerprint, sampleMachineDoc } from "./fixtures";

describe("mergeMachineCandidates", () => {
  it("deduplicates machines that appear in multiple index queries", () => {
    const fp = sampleFingerprint();
    const shared = sampleMachineDoc("machines:shared", fp);
    const vendorOnly = sampleMachineDoc("machines:vendor", fp);
    const displayOnly = sampleMachineDoc("machines:display", fp);

    const merged = mergeMachineCandidates(
      [shared, vendorOnly],
      [shared, displayOnly],
    );

    assert.deepEqual(
      merged.map((machine) => machine._id),
      ["machines:shared", "machines:vendor", "machines:display"],
    );
  });

  it("preserves first-seen order across groups", () => {
    const fp = sampleFingerprint();
    const first = sampleMachineDoc("machines:first", fp);
    const second = sampleMachineDoc("machines:second", fp);

    const merged = mergeMachineCandidates([first], [second]);
    assert.deepEqual(
      merged.map((machine) => machine._id),
      ["machines:first", "machines:second"],
    );
  });

  it("returns empty list when all groups are empty", () => {
    assert.deepEqual(mergeMachineCandidates([], []), []);
  });
});

describe("machineSummary", () => {
  it("maps stored machine docs to API summary fields", async () => {
    const fingerprint = sampleFingerprint({
      display: "3440x1440@120Hz",
      profiles: ["arch-linux"],
    });
    const machine = sampleMachineDoc("machines:abc", fingerprint, {
      machineLabel: "battlestation",
    });

    const summary = await machineSummary(machine);
    assert.deepEqual(summary, {
      machine_id: "machines:abc",
      machine_label: "battlestation",
      gpu_vendor: "nvidia",
      display: "3440x1440@120Hz",
      profiles: ["arch-linux"],
    });
  });

  it("uses empty display string when fingerprint display is missing", async () => {
    const machine = sampleMachineDoc(
      "machines:minimal",
      sampleFingerprint({ display: undefined }),
    );
    const summary = await machineSummary(machine);
    assert.equal(summary.display, "");
  });
});
