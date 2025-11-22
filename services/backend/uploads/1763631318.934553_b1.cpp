#include <openssl/evp.h>

#include <algorithm>
#include <array>
#include <cctype>
#include <cstdlib>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <map>
#include <memory>
#include <sstream>
#include <string>
#include <vector>

#define all(v) (v).begin(), (v).end()
#define rall(v) (v).rbegin(), (v).rend()

#ifdef _MSC_VER
#pragma comment(lib, "libcrypto")
#endif

using namespace std;

struct EvpMdCtxDeleter {
    void operator()(EVP_MD_CTX* ctx) const noexcept {
        if (ctx) {
            EVP_MD_CTX_free(ctx);
        }
    }
};

using EvpCtxPtr = unique_ptr<EVP_MD_CTX, EvpMdCtxDeleter>;

struct HashPlan {
    string name;
    const EVP_MD* md = nullptr;
    EvpCtxPtr ctx{nullptr};
    array<unsigned char, EVP_MAX_MD_SIZE> digest{};
    unsigned int digestLen = 0;

    HashPlan(string n, const EVP_MD* m) {
        name = move(n);
        md = m;
        ctx.reset(EVP_MD_CTX_new());
    }
    HashPlan(HashPlan&&) noexcept = default;
    HashPlan& operator=(HashPlan&&) noexcept = default;
    HashPlan(const HashPlan&) = delete;
    HashPlan& operator=(const HashPlan&) = delete;
};

struct Options {
    string mode;
    string data;
    string path;
    vector <string> algo;
    bool showHelp = false;
    bool dataProvided = false;
    bool algoProvided = false;

    Options(string mode = "", string data = "", string path = "", vector<string> algo = {}) {
        this->mode = mode;
        this->data = data;
        this->path = path;
        this->algo = algo;
    }
};  

const map<string, const EVP_MD* (*)()> kDigestFactories = {
    {"md5", &EVP_md5},
    {"sha1", &EVP_sha1},
    {"sha224", &EVP_sha224},
    {"sha256", &EVP_sha256},
    {"sha384", &EVP_sha384},
    {"sha512", &EVP_sha512},
    {"sha3-224", &EVP_sha3_224},
    {"sha3-256", &EVP_sha3_256},
    {"sha3-384", &EVP_sha3_384},
    {"sha3-512", &EVP_sha3_512},
};

string toLower(string T) {
    for (int i = 0;  i < (int)T.size(); ++i) 
        T[i] = static_cast<char>(tolower(static_cast<unsigned char>(T[i])));
    
    return T;
}

string trim(const string& value) {
    auto begin = find_if_not(all(value), [](unsigned char ch) {
        return isspace(ch);
    });
    auto end = find_if_not(rall(value), [](unsigned char ch) {
        return isspace(ch);
    }).base();
    if (begin >= end) return {};
    return string(begin, end);
}

string bytesToHex(const unsigned char* data, unsigned int length) {
    ostringstream oss;
    oss << hex << setfill('0');
    for (unsigned int i = 0; i < length; ++i) {
        oss << setw(2) << static_cast<unsigned int>(data[i]);
    }
    return oss.str();
}

string supportedAlgorithmsList(void) {
    ostringstream oss;
    bool first = true;
    for (const auto& entry : kDigestFactories) {
        if (!first) {
            oss << ", ";
        }
        first = false;
        oss << entry.first;
    }
    return oss.str();
}

bool parseArgs(int argc, char** argv, Options& options, string& errorMessage) {
    for (int i = 1; i < argc; ++i) {
        string arg = argv[i];
        if (arg == "--help" || arg == "-h") {
            options.showHelp = true;
            return true;
        } else if (arg == "--mode") {
            if (i + 1 >= argc) {
                errorMessage = "Missing value for --mode.";
                return false;
            }
            options.mode = toLower(argv[++i]);
        } else if (arg == "--data") {
            if (i + 1 >= argc) {
                errorMessage = "Missing value for --data.";
                return false;
            }
            options.data = argv[++i];
            options.dataProvided = true;
        } else if (arg == "--path") {
            if (i + 1 >= argc) {
                errorMessage = "Missing value for --path.";
                return false;
            }
            options.path = argv[++i];
        } else if (arg == "--algos") {
            if (i + 1 >= argc) {
                errorMessage = "Missing value for --algos.";
                return false;
            }
            string list = argv[++i];
            stringstream ss(list);
            string item;
            while (getline(ss, item, ',')) {
                auto cleaned = trim(item);
                if (!cleaned.empty()) {
                    options.algo.push_back(toLower(cleaned));
                }
            }
            options.algoProvided = true;
        } else {
            errorMessage = "Unknown argument: " + arg;
            return false;
        }
    }
    return true;
}

void printUsage(const char* exe) {
    cout << "Usage: " << exe << " --mode <text|hex|file> [options]\n"
              << "Options:\n"
              << "  --data <value>        Input string (text or hex mode)\n"
              << "  --path <filepath>     File path (file mode)\n"
              << "  --algos <list>        Comma-separated digest names (default: md5,sha1,sha256,sha3-256)\n"
              << "  --help                Show this help message\n"
              << "Examples:\n"
              << "  " << exe << " --mode text --data \"Ronaldo or Messi (GOAT) ?\" --algos md5,sha256,sha3-256\n"
              << "  " << exe << " --mode hex --data 48656C6C6F\n"
              << "  " << exe << " --mode file --path sample.bin --algos md5,sha1\n";

    cout << "Supported algorithms: " << supportedAlgorithmsList() << "\n";
}

bool preparePlans(const vector<string>& algorithmNames, vector<HashPlan>& plans, string& errorMessage) {
    plans.clear();
    plans.reserve(algorithmNames.size());
    for (const auto& name : algorithmNames) {
        auto it = kDigestFactories.find(name);
        if (it == kDigestFactories.end()) {
            errorMessage = "Unsupported algorithm '" + name + "'. Supported algorithms: " + supportedAlgorithmsList();
            return false;
        }
        const EVP_MD* md = it->second();
        if (!md) {
            errorMessage = "Failed to resolve OpenSSL digest for '" + name + "'.";
            return false;
        }
        HashPlan plan(name, md);
        if (!plan.ctx) {
            errorMessage = "Failed to allocate digest context for '" + name + "'.";
            return false;
        }
        if (EVP_DigestInit_ex(plan.ctx.get(), md, nullptr) != 1) {
            errorMessage = "EVP_DigestInit_ex failed for '" + name + "'.";
            return false;
        }
        plans.emplace_back(move(plan));
    }
    return true;
}

bool updatePlans(const unsigned char* data, size_t length, vector<HashPlan>& plans, string& errorMessage) {
    if (length == 0) return true;
    for (auto& plan : plans) {
        if (EVP_DigestUpdate(plan.ctx.get(), data, length) != 1) {
            errorMessage = "EVP_DigestUpdate failed for '" + plan.name + "'.";
            return false;
        }
    }
    return true;
}

bool finalizePlans(vector<HashPlan>& plans, map<string, string>& outputs, string& errorMessage) {
    for (auto& plan : plans) {
        if (EVP_DigestFinal_ex(plan.ctx.get(), plan.digest.data(), &plan.digestLen) != 1) {
            errorMessage = "EVP_DigestFinal_ex failed for '" + plan.name + "'.";
            return false;
        }
        outputs[plan.name] = bytesToHex(plan.digest.data(), plan.digestLen);
    }
    return true;
}

int HexToValue(char c) {
    if (c >= '0' && c <= '9') return c - '0';
    if (c >= 'a' && c <= 'f') return c - 'a' + 10;
    if (c >= 'A' && c <= 'F') return c - 'A' + 10;
    return -1;
}

bool parseHexString(const string& input, vector<unsigned char>& output, string& errorMessage) {
    string sanitized;
    sanitized.reserve(input.size());
    for (char ch : input) {
        if (isspace(static_cast<unsigned char>(ch))) {
            continue;
        }
        sanitized.push_back(ch);
    }
    if (sanitized.rfind("0x", 0) == 0 || sanitized.rfind("0X", 0) == 0) sanitized.erase(0, 2);
    if (sanitized.size() % 2 != 0) {
        errorMessage = "Hex input length must be even.";
        return false;
    }
    output.clear();
    output.reserve(sanitized.size() / 2);
    for (size_t i = 0; i < sanitized.size(); i += 2) {
        int high = HexToValue(sanitized[i]);
        int low = HexToValue(sanitized[i + 1]);
        if (high < 0 || low < 0) {
            errorMessage = "Invalid hexadecimal character encountered.";
            return false;
        }
        output.push_back(static_cast<unsigned char>((high << 4) | low));
    }
    return true;
}

bool processBuffer(const vector<unsigned char>& data, vector<HashPlan>& plans, map<string, string>& outputs, string& errorMessage) {
    if (!updatePlans(data.data(), data.size(), plans, errorMessage)) return false;
    return finalizePlans(plans, outputs, errorMessage);
}

bool processFile(const string& path, vector<HashPlan>& plans, map<string, string>& outputs, string& errorMessage) {
    ifstream input(path, ios::binary);
    if (!input.is_open()) {
        errorMessage = "Failed to open file '" + path + "'.";
        return false;
    }
    constexpr size_t kBufferSize = 1 << 20; // 1 MiB
    array<unsigned char, kBufferSize> buffer{};
    while (input) {
        input.read(reinterpret_cast<char*>(buffer.data()), static_cast<streamsize>(buffer.size()));
        streamsize bytesRead = input.gcount();
        if (bytesRead > 0) {
            if (!updatePlans(buffer.data(), static_cast<size_t>(bytesRead), plans, errorMessage)) {
                return false;
            }
        }
    }
    if (!input.eof()) {
        errorMessage = "Error while reading file '" + path + "'.";
        return false;
    }
    return finalizePlans(plans, outputs, errorMessage);
}

int main(int argc, char** argv) {
    Options options;
    string errorMessage;

    if (!parseArgs(argc, argv, options, errorMessage)) {
        cerr << "Error: " << errorMessage << "\n";
        printUsage(argv[0]);
        return 0;
    }

    if (options.showHelp) {
        printUsage(argv[0]);
        return 0;
    }

    if (options.mode != "text" && options.mode != "hex" && options.mode != "file") {
        cerr << "Error: --mode must be one of text, hex, or file.\n";
        printUsage(argv[0]);
        return 0;
    }

    if ((options.mode == "text" || options.mode == "hex") && !options.dataProvided) {
        cerr << "Error: --data is required for text and hex modes.\n";
        return 0;
    }

    if (options.mode == "file" && options.path.empty()) {
        cerr << "Error: --path is required for file mode.\n";
        return 0;
    }

    if (!options.algoProvided) {
        options.algo = {"md5", "sha1", "sha256", "sha3-256"};
    }

    vector<HashPlan> plans;
    if (!preparePlans(options.algo, plans, errorMessage)) {
        cerr << "Error: " << errorMessage << "\n";
        return 0;
    }

    map<string, string> outputs;

    if (options.mode == "text") {
        vector<unsigned char> buffer(options.data.begin(), options.data.end());
        if (!processBuffer(buffer, plans, outputs, errorMessage)) {
            cerr << "Error: " << errorMessage << "\n";
            return 0;
        }
    } else if (options.mode == "hex") {
        vector<unsigned char> buffer;
        if (!parseHexString(options.data, buffer, errorMessage)) {
            cerr << "Error: " << errorMessage << "\n";
            return 0;
        }
        if (!processBuffer(buffer, plans, outputs, errorMessage)) {
            cerr << "Error: " << errorMessage << "\n";
            return 0;
        }
    } else {
        if (!processFile(options.path, plans, outputs, errorMessage)) {
            cerr << "Error: " << errorMessage << "\n";
            return 0;
        }
    }

    for (const auto& algoS : options.algo) {
        auto it = outputs.find(algoS);
        if (it != outputs.end()) {
            cout << algoS << ": " << it->second << '\n';
        }
    }

    return 0;
}

// g++ -std=c++17 -O2 b1.cpp -o b1 -lcrypto
// ./b1 to show usage information
