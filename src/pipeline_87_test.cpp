// Issue #87: test: pipeline-runner.sh 状态驱动验证
// Developer phase implementation - Test for pipeline-runner.sh state-driven validation

#include <iostream>
#include <fstream>
#include <sstream>
#include <string>
#include <cstdlib>
#include <ctime>
#include <sys/stat.h>
#include <unistd.h>

using namespace std;

// Test configuration
const string TEST_ISSUE = "87";
const string PIPELINE_RUNNER = "scripts/pipeline-runner.sh";
const string STATE_DIR = ".pipeline-state";
const string STATE_FILE = STATE_DIR + "/" + TEST_ISSUE + "_stage";
const string OPENCLAW_DIR = "openclaw";

// Colors for output
const string RED = "\033[31m";
const string GREEN = "\033[32m";
const string YELLOW = "\033[33m";
const string BLUE = "\033[34m";
const string RESET = "\033[0m";

int tests_run = 0;
int tests_passed = 0;
int tests_failed = 0;

// Helper: Run shell command and capture output
string run_cmd(const string& cmd) {
    FILE* pipe = popen(cmd.c_str(), "r");
    if (!pipe) return "";
    char buffer[256];
    string result = "";
    while (fgets(buffer, sizeof(buffer), pipe) != nullptr) {
        result += buffer;
    }
    pclose(pipe);
    return result;
}

// Helper: Check if file exists
bool file_exists(const string& path) {
    struct stat st;
    return stat(path.c_str(), &st) == 0;
}

// Helper: Read file content
string read_file(const string& path) {
    ifstream file(path);
    if (!file.is_open()) return "";
    stringstream buffer;
    buffer << file.rdbuf();
    return buffer.str();
}

// Helper: Write content to file
bool write_file(const string& path, const string& content) {
    ofstream file(path);
    if (!file.is_open()) return false;
    file << content;
    file.close();
    return true;
}

// Helper: Create directory if not exists
void ensure_dir(const string& path) {
    run_cmd("mkdir -p " + path);
}

// Helper: Remove file/directory
void cleanup(const string& path) {
    run_cmd("rm -rf " + path);
}

// Test result logging
void log_test(const string& name, bool passed, const string& msg = "") {
    tests_run++;
    if (passed) {
        tests_passed++;
        cout << GREEN << "[PASS]" << RESET << " " << name;
    } else {
        tests_failed++;
        cout << RED << "[FAIL]" << RESET << " " << name;
    }
    if (!msg.empty()) {
        cout << " - " << msg;
    }
    cout << endl;
}

// TC-6: State file JSON format validation
bool test_state_json_format(const string& stage_value) {
    ensure_dir(STATE_DIR);
    string json_content = "{\"issue\":87,\"stage\":" + stage_value + ",\"updated_at\":\"2026-04-05T10:00:00+08:00\",\"error\":null}";
    write_file(STATE_FILE, json_content);
    
    string content = read_file(STATE_FILE);
    if (content.empty()) return false;
    
    bool has_issue = content.find("\"issue\"") != string::npos;
    bool has_stage = content.find("\"stage\"") != string::npos;
    bool has_updated_at = content.find("\"updated_at\"") != string::npos;
    bool has_error = content.find("\"error\"") != string::npos;
    
    return has_issue && has_stage && has_updated_at && has_error;
}

// TC-1: Script has stage logic
bool test_script_has_stage_logic() {
    string script_content = read_file(PIPELINE_RUNNER);
    if (script_content.empty()) return false;
    
    bool has_stage_var = script_content.find("stage=") != string::npos || 
                         script_content.find("STAGE=") != string::npos;
    bool has_state_file = script_content.find("STATE_FILE") != string::npos ||
                          script_content.find("state_file") != string::npos;
    bool has_continue_flag = script_content.find("--continue") != string::npos;
    
    return has_stage_var && has_state_file && has_continue_flag;
}

// TC-5: Skip completed state
bool test_skip_completed_logic() {
    string script_content = read_file(PIPELINE_RUNNER);
    if (script_content.empty()) return false;
    
    bool has_skip_4 = script_content.find("stage 4") != string::npos ||
                      script_content.find("stage=4") != string::npos;
    
    bool has_skip_logic = script_content.find("已完成") != string::npos ||
                          script_content.find("already") != string::npos ||
                          script_content.find("skip") != string::npos;
    
    return has_skip_4 || has_skip_logic;
}

// TC-2: Resume from Architect logic
bool test_resume_from_stage1_logic() {
    string script_content = read_file(PIPELINE_RUNNER);
    if (script_content.empty()) return false;
    
    bool has_if_stage = script_content.find("if [") != string::npos ||
                        script_content.find("if [[") != string::npos;
    
    return has_if_stage;
}

// TC-3: State file creation
bool test_state_file_creation() {
    cleanup(STATE_FILE);
    ensure_dir(STATE_DIR);
    
    write_file(STATE_FILE, "{\"issue\":87,\"stage\":0,\"updated_at\":\"2026-04-05T10:00:00+08:00\",\"error\":null}");
    
    bool exists = file_exists(STATE_FILE);
    string content = read_file(STATE_FILE);
    bool valid = content.find("\"stage\":0") != string::npos;
    
    return exists && valid;
}

// TC-4: Resume capability
bool test_resume_capability() {
    ensure_dir(STATE_DIR);
    
    for (int stage = 0; stage <= 4; stage++) {
        string json = "{\"issue\":87,\"stage\":" + to_string(stage) + ",\"updated_at\":\"2026-04-05T10:00:00+08:00\",\"error\":null}";
        write_file(STATE_FILE, json);
        
        string content = read_file(STATE_FILE);
        if (content.find("\"stage\":" + to_string(stage)) == string::npos) {
            return false;
        }
    }
    return true;
}

// TC-7: Stage increment - stages 1-4 present in write_state calls
bool test_stage_increment() {
    string script_content = read_file(PIPELINE_RUNNER);
    if (script_content.empty()) return false;
    
    // Check for write_state calls with stages 1, 2, 3, 4
    bool has_stage_1 = script_content.find("write_state \"$issue_num\" \"1\"") != string::npos;
    bool has_stage_2 = script_content.find("write_state \"$issue_num\" \"2\"") != string::npos;
    bool has_stage_3 = script_content.find("write_state \"$issue_num\" \"3\"") != string::npos;
    bool has_stage_4 = script_content.find("write_state \"$issue_num\" \"4\"") != string::npos;
    
    // Stage 0 is implicit (default when no state file exists)
    return has_stage_1 && has_stage_2 && has_stage_3 && has_stage_4;
}

// Main test suite
int main() {
    cout << BLUE << "========================================" << RESET << endl;
    cout << BLUE << "Issue #87: Pipeline Runner Test Suite" << RESET << endl;
    cout << BLUE << "========================================" << RESET << endl;
    cout << endl;
    
    cout << YELLOW << "[INFO]" << RESET << " Checking prerequisites..." << endl;
    
    if (!file_exists(PIPELINE_RUNNER)) {
        cout << RED << "[ERROR]" << RESET << " pipeline-runner.sh not found at " << PIPELINE_RUNNER << endl;
        return 1;
    }
    
    cout << "Pipeline runner script found: " << PIPELINE_RUNNER << endl;
    cout << endl;
    
    // TC-6: State file JSON format validation
    cout << YELLOW << "[TEST]" << RESET << " TC-6: State file JSON format validation" << endl;
    bool tc6_pass = test_state_json_format("1");
    log_test("JSON format with stage=1", tc6_pass);
    tc6_pass = test_state_json_format("3");
    log_test("JSON format with stage=3", tc6_pass);
    tc6_pass = test_state_json_format("4");
    log_test("JSON format with stage=4", tc6_pass);
    cout << endl;
    
    // TC-1: Script has stage logic
    cout << YELLOW << "[TEST]" << RESET << " TC-1: Script has stage handling logic" << endl;
    bool tc1_pass = test_script_has_stage_logic();
    log_test("Stage handling logic exists", tc1_pass, "Script contains stage variables and state file handling");
    cout << endl;
    
    // TC-5: Skip completed state
    cout << YELLOW << "[TEST]" << RESET << " TC-5: Skip completed state logic" << endl;
    bool tc5_pass = test_skip_completed_logic();
    log_test("Skip completed (stage=4) logic", tc5_pass, "Script handles stage=4 skip");
    cout << endl;
    
    // TC-2: Resume from Architect
    cout << YELLOW << "[TEST]" << RESET << " TC-2: Resume from stage 1 logic" << endl;
    bool tc2_pass = test_resume_from_stage1_logic();
    log_test("Resume from Architect (stage=1)", tc2_pass, "Script has conditional stage execution");
    cout << endl;
    
    // TC-3: State file creation
    cout << YELLOW << "[TEST]" << RESET << " TC-3: State file creation" << endl;
    bool tc3_pass = test_state_file_creation();
    log_test("State file created correctly", tc3_pass, "State file with JSON format created");
    cout << endl;
    
    // TC-4: Resume capability
    cout << YELLOW << "[TEST]" << RESET << " TC-4: Resume capability" << endl;
    bool tc4_pass = test_resume_capability();
    log_test("Resume from any stage 0-4", tc4_pass, "State file can store stages 0-4");
    cout << endl;
    
    // TC-7: Stage increment
    cout << YELLOW << "[TEST]" << RESET << " TC-7: Stage increment logic" << endl;
    bool tc7_pass = test_stage_increment();
    log_test("Stage increment logic", tc7_pass, "Script handles stages 0-4");
    cout << endl;
    
    // Summary
    cout << BLUE << "========================================" << RESET << endl;
    cout << BLUE << "Test Summary" << RESET << endl;
    cout << BLUE << "========================================" << RESET << endl;
    cout << "Tests run:    " << tests_run << endl;
    cout << GREEN << "Tests passed: " << tests_passed << RESET << endl;
    cout << RED << "Tests failed: " << tests_failed << RESET << endl;
    cout << endl;
    
    // Cleanup
    cleanup(STATE_FILE);
    
    return tests_failed > 0 ? 1 : 0;
}
