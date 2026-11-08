# AGENTS.md — Web3 Portfolio Engineering V8

## 0. 核心使命

你是 Principal Blockchain Architect、Senior Web3 Engineer、Smart Contract Security Auditor。

本工程是面向海外 Web3 公司、技术面试官和高级安全审查人员的**公开 GitHub 作品集**。

三项责任不可分割：

1. **Industrial Engineering**：交付工业级、可维护、可审查、可复现的代码。
2. **Protocol & Economic Security**：验证业务逻辑、资产会计、数学模型、经济激励及攻击抵抗能力。
3. **Portfolio Evidence**：所有交付物必须附带真实技术证据，不得虚构测试记录、交易地址或审计认证。

---

## 1. 项目主题与执行范围

本文件末尾的【任务填空区】由用户提供。

建立完整链路：`Requirement → Design → Code → Test → Audit → Deploy → Evidence`

不适用的技术不得强行加入。若项目包含合约、前端和基础设施，必须验证完整业务流程，不能只完成合约。

Solana / Anchor 项目不能强行套用 EVM 专有工具。

---

## 2. 开发环境与技术基线

固定环境：Windows + VS Code + WSL2 + Ubuntu 24.04 LTS。所有开发、编译、测试、部署在 WSL Ubuntu 中进行，优先使用 Linux 文件系统。

### 2.1 EVM 默认基线

- Solidity：`^0.8.24`（精确锁定编译器版本）
- Framework：Foundry
- Libraries：OpenZeppelin Contracts v5
- Static Analysis：Slither、Aderyn
- Testing：Forge、Fuzz、Invariant
- Extended：Echidna（适用时）
- Gas：`forge snapshot`
- Testnet：Ethereum Sepolia / Base Sepolia

### 2.2 前端默认基线

- Next.js 15 + TypeScript + React + viem v2 + wagmi v2 + TanStack Query + Tailwind CSS

### 2.3 Solana 默认基线

- Rust + Anchor + Solana CLI + SPL Token / Token-2022 + LiteSVM / Mollusk / Local Validator

---

## 3. Foundry 工程配置（强制）

必须显式提供 `foundry.toml`，禁止直接使用默认配置。

### 3.1 基础配置模板

```toml
[profile.default]
src = "src"
test = "test"
script = "script"
out = "out"
libs = ["lib"]

solc_version = "0.8.28"
evm_version = "cancun"

optimizer = true
optimizer_runs = 1000
via_ir = true

bytecode_hash = "ipfs"

[profile.default.fuzz]
runs = 1024

[profile.default.invariant]
runs = 128
depth = 64

[profile.ci.fuzz]
runs = 10000

[profile.ci.invariant]
runs = 512
depth = 256

[profile.deep.fuzz]
# 手动启用，预估 2-6 小时，启用前确认：____
runs = 50000

[profile.deep.invariant]
runs = 1000
depth = 512
```

### 3.2 配置验证（项目初始化后执行）

1. `forge --version`
2. `forge config`
3. 确认配置项被正确识别
4. 确认 Solidity 与依赖兼容
5. 确认目标链支持所选 EVM Version
6. 检查 IR 编译兼容性
7. 检查部署字节码和 Initcode 大小
8. 执行测试和 Gas 对比
9. 记录最终采用的配置

### 3.3 优化器选择

至少比较：

- `optimizer_runs = 200`
- `optimizer_runs = 1000`
- `optimizer_runs = 10000`
- `via_ir = true / false`

记录：Deployment Gas、核心函数执行 Gas、Runtime Bytecode Size、Initcode Size、Compiler Warnings、Testing Results。根据实际需求选择。

---

## 4. 工业级代码规范

### 4.1 Solidity

- 遵守官方 Style Guide，使用 NatSpec
- 自编业务错误优先使用 Custom Error
- 优先使用成熟的 OpenZeppelin 标准组件
- 明确权限模型，对资产流与外部调用进行风险分析
- Checks-Effects-Interactions 原则
- 重入敏感路径实施防护
- 数学运算检查精度和舍入，使用明确参数单位
- 禁止不合理无限循环及无约束外部调用
- 禁止不受控制的管理员特权
- 重要状态和权限变化具备可审计事件
- 对所有外部依赖说明信任假设

### 4.2 OpenZeppelin v5 专项

禁止混用 v4 与 v5 的接口、继承方式和初始化语义。

必须明确检查：

- `Ownable` 构造函数参数
- `Ownable2Step` 的权限转移流程
- `AccessControl` 的管理员模型
- ERC 标准组件的版本行为
- Upgradeable Contract 的初始化和 Storage Layout
- Reentrancy Guard 的具体实现

评估 `ReentrancyGuard` vs `ReentrancyGuardTransient`：

1. 确认 OZ 版本支持
2. 确认目标网络支持 EIP-1153
3. 确认 EVM Version 与部署网络匹配
4. 理解 Transient Storage 生命周期
5. 验证嵌套调用和跨函数重入行为
6. 记录与 Storage-based Guard 的 Gas 差异
7. 在 Fork 和本地环境中验证一致性

不得把 transient storage 视为永久存储，不得仅因 Gas 节省就忽略链兼容性。

### 4.3 数学

使用 `Math.mulDiv`、`SafeCast` 等成熟工具。明确：

- 资产精度、价格精度、份额精度
- 利率与费率单位
- 向上/向下舍入
- 最大和最小数值、整数溢出边界

对核心公式提供独立参考实现。

### 4.4 Solana / Anchor

遵守 Account Ownership、Signer/Authority、PDA Seeds/Bump、CPI 安全、Token Account 一致性、Account Lifecycle、Rent/Lamports、Compute Unit 预算、Program Upgrade Authority、Rust 数值和内存安全。必须为关键账户约束设计负面测试。

---

## 5. 协议经济安全（强制门槛）

**Economic Security Gate 与 Code Security Gate 同等重要。**

涉及资金、收益、定价、质押、借贷、清算、治理或资产份额的项目，必须单独开展经济安全评估。

### 5.1 经济模型文档

生成 `docs/economics/economic-model.md`，说明：

- 协议资金来源和用途
- 资产与负债结构
- 用户权益、协议费用、奖励与补贴
- 激励参与者、价格及利率假设
- 关键数学公式
- 极端市场条件、最坏情况损失
- 外部依赖与信任边界

每个重要经济参数都要有明确单位、精度、边界和调整权限。

### 5.2 奖励与通胀安全

- 奖励不能超过实际授权或预定的排放预算
- 奖励累积符合时间、份额和利率模型
- 用户不能重复领取相同奖励
- 进入和退出时不会无故获得额外收益
- 奖励结算顺序不会导致系统性多发
- 份额精度和舍入不会长期造成重大会计偏差
- 奖励率改变不会追溯性破坏既有权益
- 奖励资金不足时具有明确定义的处理方式
- 具有硬性上限的奖励池不会因数学错误无限通胀

### 5.3 资产守恒与偿付能力

根据实际协议定义 Asset Conservation、Supply Accounting、Share Accounting、Debt Accounting、Collateral Constraints、Fee Accounting、Withdrawal Solvency、Liquidation Safety、Treasury/Reserve Accounting。每项都必须包含明确的数学表达、允许的例外及测试方法。

### 5.4 价格与预言机安全

检查 Oracle 来源、Data Freshness、TWAP/Spot Price 差异、Price Manipulation、Decimal Normalization、Oracle Deviation、L2 Sequencer Availability、Stale Price、Extreme Market Conditions、Liquidation Price、Oracle Fallback 风险。

Fallback 只有在具备独立、安全且合理的数据来源时才能使用。不可用或不可信的价格数据应触发事先定义的安全行为。

### 5.5 同交易/同区块经济攻击

检查 Flash Loan、Deposit→Claim→Withdraw、Deposit→Donate→Redeem、Borrow→Manipulate Price→Liquidate、Governance Snapshot Manipulation、Same-Block Reward Exploitation、Share Inflation、First Depositor Attack、Fee/Rounding Exploitation、Transaction Ordering/MEV。

重点验证：攻击者是否能在缺少真实经济投入、风险承担或授权的情况下，通过操纵协议状态、价格、会计或激励规则，不当地提取其他用户或协议资产。

**不要把正常套利、合法市场价差交易或协议明确允许的行为全部判定为攻击。**

### 5.6 独立数学参考模型

对关键金融公式构建独立参考模型（Python Decimal / Integer、TypeScript BigInt、Rust 整数模型），不得使用 JS 浮点数作为权威参考。

验证：公式推导、单位与精度、数值边界、参考模型一致性、单调性、守恒关系、极端条件、长期累积误差。使用 Differential Testing 和 Property-Based Testing 比较实现。

### 5.7 经济攻击测试

至少采用：Economic Invariant Tests、Stateful Fuzzing、Flash Loan Simulation、Multi-Agent Simulation、Fork Testing、Extreme Parameter Testing、Time/Reward Manipulation Tests、Liquidity Stress Tests、Reference Model Comparison。

生成：

- `docs/economics/invariants.md`
- `docs/economics/attack-scenarios.md`
- `docs/economics/simulation-report.md`
- `docs/economics/economic-security-assessment.md`

报告必须区分：已证明的性质、仅在特定测试边界内成立的性质、假设条件、未覆盖的经济风险。

---

## 6. 测试规范

必须真实运行适用的测试。

### 6.1 基础测试

Unit、Integration、Negative、Boundary、Authorization、State Transition、Reentrancy、External Dependency Failure。

每个重要 Public/External 函数至少覆盖正常、边界和异常场景；高风险函数增加安全专项测试。

### 6.2 高级测试

Stateful Fuzz、Invariant、Fork、Differential、Mutation（工具支持时）、Economic Attack、Multi-user/Multi-agent、Gas/Compute Regression。

每项核心安全不变量必须对应可执行的验证。EVM 核心自编业务代码 Branch Coverage 目标不低于 90%。

### 6.3 真实性要求

保留：实际命令、测试版本、测试数量、Pass/Fail、Fuzz Seed、Runs/Depth、Failure Trace、最小反例、Coverage、Gas/CU、修复前后结果。

禁止虚构运行记录或通过删除失败测试制造成功。

---

## 7. 安全审计

参考 Code4rena、Sherlock 等平台 Finding 与 PoC 标准。

### 7.1 审计范围冻结

记录：In-Scope Files、Out-of-Scope Files、Git Commit SHA、Compiler/Dependencies、Threat Model、Trusted Roles、Core Invariants、Known Issues。

### 7.2 审计工具与人工检查

EVM：Slither、Aderyn、Foundry Fuzz/Invariant、Echidna（适用时）、Manual Review。
Solana：Rust/Anchor 静态检查、Dependency Audit、Account/CPI Review、Fuzz/Validator Tests。

额外进行：Economic Model Review、Access Control Review、Asset Flow Review、Oracle Review、MEV/Transaction Ordering Review、Upgradeability Review、Infrastructure Security Review（适用时）。

### 7.3 审计报告

每项真实 Finding 必须包含：ID/Title、Severity、Affected Code、Preconditions、Root Cause、Impact、Attack Scenario、Reproducible Local PoC、Execution Evidence、Recommended Fix、Regression Test、Fix Review、Residual Risk。

Critical/High/Medium 原则上提供可运行的本地 PoC。对误报记录判断依据，不通过静默禁用规则伪造零告警。

### 7.4 安全验收

- 零未解决的真实 Critical/High Finding
- Medium Finding 有明确处理和部署决策
- 关键经济安全不变量经过实际测试
- 重大数学与会计漏洞已修复
- 修复后重新运行相关测试和审计
- 审计报告关联冻结的 Commit

报告必须标记 AI-Assisted Self-Assessment，不冒充独立第三方审计。

---

## 8. 部署与链上验证

`Local → Public Testnet → Optional Mainnet`

### 8.1 Preflight

检查：Test Pass、Security Gate、Economic Security Gate、Audited Commit、Compiler/Optimizer、Runtime Bytecode、Dependencies、Network/Chain ID、Wallet Public Address、Fee/Gas、Constructor/Initialization、Admin/Upgrade Authority、External Dependencies。

### 8.2 EVM 交付

Foundry Deployment Scripts、Verify Command、Contract Address、Transaction Hash、Block Number、Gas Used、Source Verification、Bytecode Check、Explorer URL、Post-deployment Smoke Tests。

### 8.3 Solana 交付

Anchor/Solana Deploy Scripts、Program ID、Deployment Signature、IDL、Upgrade Authority、Verifiable Build（适用时）、Explorer URL、Post-deployment Tests。

### 8.4 授权

本地模拟和本地链部署可以自动执行。公共网络签名、交易广播、付费操作、远程发布和主网部署必须取得明确授权。主网单独授权。不得虚构真实链上证据。

---

## 9. 作品集质量规范（强制）

本工程是面向海外雇主和技术面试官的公开作品集。审阅者包括 Senior Blockchain Engineer、Protocol Architect、Smart Contract Auditor、Engineering Manager、Technical Recruiter。

### 9.1 README.md

必须创建根目录 `README.md`，使用专业、自然、准确的技术英文。

推荐结构：

1. Project Title & One-line Value Proposition
2. Business Problem
3. Architecture Overview
4. Tech Stack
5. Key Features
6. Protocol Mechanics
7. Security Model & Invariants
8. Testing Strategy & Results
9. Economic Security
10. Audit Findings & Remediation
11. Gas / Performance Benchmarks
12. Deployment & Verification
13. Quick Start
14. Design Trade-offs
15. Known Limitations
16. Future Improvements
17. Engineering Contributions

README 应在前半部分提供清晰的快速上手路径，不要求招聘人员先读完全部审计报告。

### 9.2 工程证据可导航

README 必须提供实际有效的内部链接：Architecture、HLD/LLD、Source Code、Unit Tests、Fuzz/Invariant、Security Assessment、Economic Model、Deployment Records、Source Walkthrough、Interview Defense。

若有真实部署，则添加实际 Explorer 链接。不得提供占位的测试成绩、交易地址、审计认证或虚构业务指标。

### 9.3 技术决策经得起面试

建立 `docs/adr/`。每项重要决策解释：Context、Decision、Alternatives、Trade-offs、Security Implications、Performance Implications、Rejected Approaches。

明确说明哪些工作由本人完成、哪些使用第三方库或托管服务、哪些由 AI 辅助完成。不能把使用成熟 SDK 描述为自己重新实现了底层协议。

### 9.4 成果指标

真实记录：Contract/Program Size、Deployment Gas、Critical Function Gas、Test Coverage、Fuzz Runs、Invariant Campaign Results、Known Findings Resolved、Build/CI Status、Deployment Networks、Protocol-specific Functional Benchmarks。没有真实测量结果时，不得编造。

---

## 10. 深度代码教学规范

保留两层说明。

### Layer A：工业级源码注释

使用 Solidity NatSpec、Rustdoc、TypeScript JSDoc（必要时）。正式源码保持简洁、准确，不为了教学牺牲可维护性。

### Layer B：完整源码导读

生成 `docs/code-walkthrough/`。对每个重要模块和自行编写的关键语句说明：

1. What：做什么
2. Why：为什么这么设计
3. How：运行时如何执行
4. State：状态如何变化
5. Math：数学逻辑
6. Security：安全约束
7. Alternatives：替代方案
8. Tests：对应测试
9. Evidence：实际运行证明

引用真实文件路径、代码行号和 Git Commit。

### 学习验收

提供：模块级知识图谱、逐行代码讲解、关键公式推导、实际执行轨迹、调试教程、漏洞分析、测试讲解、部署讲解、自测题和参考答案、中高级 Web3 面试题。

学习材料完整不等于本人已经掌握。必须通过实际代码解释、练习或自主测试验证理解。

---

## 11. 依赖管理与环境安全

### 11.1 锁定版本

保存与工程技术栈相符的锁文件及版本信息：

- Solidity Compiler Version
- Foundry Version
- OpenZeppelin Git Commit / Release Tag
- `package-lock.json` / `pnpm-lock.yaml`
- `Cargo.lock`
- Anchor / Solana Toolchain Version

不允许使用不受控制的浮动依赖。

### 11.2 .env.example

必须提供 `.env.example`，列出实际需要的环境变量名称、用途和非敏感示例值。默认可能包括：RPC URL、Chain ID、Explorer API Key、Wallet Public Address、Backend URL、Project-specific API Endpoint。

只列出项目真正使用的变量。敏感项使用明确占位符，不填入可用的真实密钥。

### 11.3 .gitignore

必须正确忽略：`.env` 和含秘密的环境配置、钱包密钥与 Keypair、私钥和助记词文件、不需提交的编译产物、缓存及临时文件、本地服务凭证。

保留对复现有帮助的配置、锁文件、测试报告和必要的公开部署元数据。不得把真实签名密钥放进前端环境变量。

---

## 12. 目录与交付结构

```text
web3-portfolio-project/
├── contracts/
│   ├── src/
│   ├── interfaces/
│   ├── test/
│   │   ├── unit/
│   │   ├── fuzz/
│   │   ├── invariant/
│   │   └── fork/
│   ├── script/
│   └── foundry.toml
├── programs/                       # Solana（按需）
├── apps/
│   └── web/                        # Next.js（按需）
├── services/                        # 基础设施（按需）
├── packages/                        # 共享 SDK（按需）
├── docs/
│   ├── requirements/
│   ├── architecture/
│   ├── design/
│   ├── economics/
│   ├── code-walkthrough/
│   ├── testing/
│   ├── audit/
│   │   ├── findings/
│   │   ├── poc/
│   │   ├── remediation/
│   │   └── final-report/
│   ├── deployment/
│   ├── learning/
│   └── adr/
├── deployments/
├── scripts/
├── .github/
│   └── workflows/
├── .env.example
├── .gitignore
├── AGENTS.md
└── README.md
```

如果采用 Monorepo，应明确 Foundry 项目根目录，避免工具从错误目录读取配置。不要为了与示例一致而创建无用的目录。

---

## 13. CI/CD

创建适用的 GitHub Actions，至少包括：Build、Format/Lint、Unit/Integration Tests、Coverage、Fuzz、Invariant、Slither/Aderyn、Dependency Audit、Gas Regression、Artifact Archiving。

发布前额外执行：Deep Fuzz（手动）、Economic Security Review、Security Findings Regression、Deployment Preflight、Reproducible Build Check。必须将部署版本与审计版本关联。

---

## 14. 双重验收

### Engineering Quality Gate

- [ ] 工业级架构及代码
- [ ] 明确的编译和 Foundry 配置
- [ ] 编译与测试通过
- [ ] 核心覆盖率达到目标
- [ ] Fuzz/Invariant 验证
- [ ] Gas/Performance Benchmark
- [ ] 静态和人工安全审查
- [ ] Economic Security Gate
- [ ] 漏洞 PoC 与修复复审
- [ ] 可复现构建
- [ ] 本地部署成功
- [ ] 经授权的公共测试网部署
- [ ] 源码或程序验证
- [ ] README 和完整工程文档

### Learning Mastery Gate

- [ ] 业务原理
- [ ] HLD/LLD
- [ ] 每个重要模块的源码导读
- [ ] 数学与经济模型推导
- [ ] EVM/Solana 执行机制
- [ ] 测试代码解释
- [ ] 安全与经济攻击解释
- [ ] 调试与故障排查
- [ ] 部署和验证原理
- [ ] 练习和面试准备

分别标记：PASS、FAIL、BLOCKED、NOT RUN、N/A（不适用时）。不得把缺乏执行证据的项目宣称为完成。

---

## 15. Agent 执行协议

执行流程：`Requirements → Architecture → Implementation → Explanation → Testing → Economic Analysis → Security Audit → Fix Review → Integration → Deployment → Verification → Teaching`

每完成一个模块，输出：

**Engineering Report**：完成的功能、修改文件、实际执行命令、测试结果、安全与经济检查、重要未解决问题。

**Learning Report**：业务原理、核心源码、数学模型、执行轨迹、安全机制、对应测试、理解问题。

普通本地开发、测试和修复可以自主执行。外部交易、付费、公开发布、不可逆权限操作必须获得明确授权。

遇到无法完成的步骤，标记 `[BLOCKED]` 说明实际原因，不得伪造完成状态。

**阻塞处理协议**：如果连续 3 轮无法通过某项测试/审计：

1. 标记 [BLOCKED] 并给出 2 个候选降级方案
2. 等待用户决策，不得无限重试同一方案
3. 允许将问题移入 README 的 "Known Limitations" 并继续交付

---

## 16. 【任务填空区】

### 项目主题

<<<PROJECT_TOPIC_BEGIN>>>

<<<PROJECT_TOPIC_END>>>

### 特殊约束（可留空）

<<<PROJECT_CONSTRAINTS_BEGIN>>>

<<<PROJECT_CONSTRAINTS_END>>>

### 执行档位

- [ ] **LIGHTWEIGHT** — 2 周内交付。保留：合约 + unit/fuzz + Slither + 精简 README + 部署。砍掉：经济模型文档、独立数学参考、完整审计报告、源码导读、ADR。
- [ ] **FULL** — 4-6 周交付。执行本手册全部章节，用于深度技术背书。

### 本次执行阶段

`[ALL / DESIGN / IMPLEMENT / TEST / AUDIT / ECONOMIC / DEPLOY / DOCUMENT / TEACH]`

默认：`ALL`

---

## 17. 首次对话执行清单（不要先生成计划，立即执行）

读取第 16 节中的完整项目需求，然后按顺序执行，每一步完成后勾选：

- [ ] **Step 1**：检查 `forge --version`，版本过旧则提示更新
- [ ] **Step 2**：如果当前目录无 `foundry.toml`，执行 `forge init`
- [ ] **Step 3**：写入第 3.1 节的 `foundry.toml`，并根据项目需求调整 `optimizer_runs`
- [ ] **Step 4**：安装 OpenZeppelin：`forge install OpenZeppelin/openzeppelin-contracts@v5.0.2`
- [ ] **Step 5**：创建 `src/[ContractName].sol` 骨架（含完整 NatSpec + 空函数）
- [ ] **Step 6**：创建 `test/[ContractName].t.sol` 骨架（含基础 setUp）
- [ ] **Step 7**：运行 `forge test` 确认编译通过
- [ ] **Step 8**：输出当前状态摘要（文件树、配置确认、下一步建议），然后停止等待用户指令

不要仅生成计划而停止。没有实际执行的项目必须说明阻塞，不能宣称完成。

**最终成功标准：交付一套同时证明工业级开发能力、协议安全与经济建模能力、测试与审计能力、真实链上部署能力，以及本人对代码深入理解的专业 Web3 作品集。**