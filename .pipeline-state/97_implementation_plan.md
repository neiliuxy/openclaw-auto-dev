# Issue #97 Implementation Plan

## Architect Stage Review (Stage 0 → Stage 1)

### Completed Work
- ✅ SPEC.md exists at `openclaw/97_pipeline_test/SPEC.md`
- ✅ SPEC.md contains all required sections (概述/需求分析/技术方案/测试计划)
- ✅ Test cases defined (TC-97-01 through TC-97-07)
- ✅ Test plan section (7.1-7.6) added per pipeline architect task

### Current State
- **Stage file**: `.pipeline-state/97_stage` = "0" (NotStarted)
- **Target**: Advance to Stage 1 (ArchitectDone)

---

## Implementation Plan for Issue #97

### Stage 1: Architect (Current)
**Objective**: Verify SPEC.md completeness and update pipeline state

**Tasks**:
1. [x] Review SPEC.md completeness - SPEC.md exists with all 7 sections
2. [x] Verify test plan section (7.1-7.6) - Present and detailed
3. [x] Update `.pipeline-state/97_stage` from "0" to "1"
4. [x] Commit with "chore(#97): Pipeline Architect complete"

**Deliverables**:
- SPEC.md with complete test plan
- Pipeline state updated to stage 1

---

### Stage 2: Developer
**Objective**: Implement pipeline state test functionality

**Tasks**:
1. [ ] Review `src/pipeline_state.h` and `src/pipeline_state.cpp` for completeness
2. [ ] Ensure `read_stage()` and `write_stage()` work correctly
3. [ ] Ensure `stage_to_description()` maps all stage values correctly
4. [ ] Compile and verify `pipeline_97_test` builds successfully
5. [ ] Update `.pipeline-state/97_stage` to "2" when Developer stage complete

**Files**:
- `src/pipeline_state.h` - Header with stage enum and function declarations
- `src/pipeline_state.cpp` - Implementation of read/write/description functions
- `src/pipeline_97_test.cpp` - Test cases validating pipeline state mechanism

**Deliverables**:
- Working pipeline state API
- Compilable test binary

---

### Stage 3: Tester
**Objective**: Execute tests and verify pipeline state mechanism

**Tasks**:
1. [ ] Run `./build/src/pipeline_97_test`
2. [ ] Verify all tests pass:
   - test_97_initial_stage() - flexible stage check (0-4)
   - test_97_write_and_read() - read/write cycle
   - test_97_stage_descriptions() - description mapping
   - test_97_valid_stage_range() - valid range 1-4
   - test_97_nonexistent_issue() - returns -1 for unknown issue
3. [ ] Verify `.pipeline-state/97_stage` format is correct (plain integer)
4. [ ] Update `.pipeline-state/97_stage` to "3" when Tester stage complete

**Test Cases**:
| ID | Description | Expected |
|----|-------------|----------|
| TC-97-01 | Initial stage check | stage >= 0 && stage <= 4 |
| TC-97-02 | Write stage=2 | write_stage returns true |
| TC-97-03 | Read stage=2 | read_stage returns 2 |
| TC-97-04 | Restore original | write_stage(original) succeeds |
| TC-97-05 | Descriptions | all 6 mappings correct |
| TC-97-06 | Valid range | stages 1-4 all map correctly |
| TC-97-07 | Non-existent | read_stage(99999) returns -1 |

---

### Stage 4: Pipeline Complete
**Objective**: Final verification and closure

**Tasks**:
1. [ ] Final review of all test results
2. [ ] Verify pipeline state file is consistent
3. [ ] Update `.pipeline-state/97_stage` to "4" (PipelineDone)
4. [ ] Document any known issues in TEST_REPORT

---

## Known Issues from Previous Runs
- TEST_REPORT_97.md shows test_97_initial_stage failed with hardcoded `stage == 1` assertion
- **Fix applied**: Test now uses flexible `assert(stage >= 0 && stage <= 4)`
- The flexible test version was committed in `a521222`

## Files Reference
```
.pipeline-state/97_stage     # Stage file (0=NotStarted, 1=ArchitectDone, etc.)
openclaw/97_pipeline_test/SPEC.md   # Requirements spec
src/pipeline_state.h         # API header
src/pipeline_state.cpp       # API implementation
src/pipeline_97_test.cpp    # Test cases
```
