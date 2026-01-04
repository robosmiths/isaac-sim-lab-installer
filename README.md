# Isaac Sim & Lab Installer

Automated installation scripts for NVIDIA Isaac Sim and Isaac Lab on Linux. One-command setup for robotics simulation and reinforcement learning.

## 🎯 What This Does

This repository provides automated bash scripts to install:

- **Isaac Sim 5.1.0** - NVIDIA's robotics simulation platform
- **Isaac Lab** - Unified framework for robot learning

## 📋 Prerequisites

### System Requirements

- **OS**: Ubuntu 22.04+ (GLIBC 2.35+)
- **Architecture**: x86_64 or aarch64
- **Disk Space**: ~50GB free
- **RAM**: 16GB+ recommended
- **GPU**: NVIDIA GPU with latest drivers

### Install Required Packages

```bash
sudo apt update
sudo apt install -y wget unzip git build-essential cmake
```

## 🚀 Quick Start

### 1. Clone This Repository

```bash
git clone https://github.com/robosmiths/isaac-sim-lab-installer.git
cd isaac-sim-lab-installer
chmod +x *.sh
```

### 2. Install Isaac Sim

```bash
./install_isaac_sim.sh
```

**What it does:**
- Downloads Isaac Sim binary (~8-10GB)
- Extracts to `~/workspace/isaacsim-5.1.0/`
- Creates symlink at `~/workspace/isaac-sim`
- **Time:** ~30-60 minutes

### 3. Install Isaac Lab

```bash
./install_isaac_lab.sh
```

**What it does:**
- Clones Isaac Lab from GitHub
- Creates Python 3.11 virtual environment using `uv`
- Links to Isaac Sim installation
- Installs RL frameworks (RSL-RL recommended)
- **Time:** ~15-25 minutes

### 4. Optimize System Performance (Optional - Only if you have performance issues)

**⚠️ WARNING:** Review the scripts carefully before running. These configurations modify system-level power management settings and may affect other parts of your system. 

For maximum Isaac Sim performance, configure CPU and GPU power management:

```bash
# Configure CPU for performance mode (TLP)
sudo ./configure_cpu_power.sh

# Restore full GPU power limits
sudo ./configure_gpu_power.sh
```

**What it does:**
- **CPU**: Sets performance governor on AC power, enables turbo boost
- **GPU**: Restores full power limits (e.g., 95W → 175W for RTX 4070)
- **Impact**: Significantly improves simulation performance

See [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for detailed power management issues and solutions.

## ✅ Testing Your Installation

### Test Isaac Sim (GUI)

Launch Isaac Sim GUI:
```bash
cd ~/workspace/isaac-sim
./isaac-sim.sh
```

**Try this in the GUI:**
1. **Create > Environment > Simple Room**
2. **Create > Robots > Franka Emika Panda Arm**
3. Click **Play** button to start simulation

### Test Isaac Lab

Activate the virtual environment and test:

```bash
cd ~/workspace/IsaacLab
source env_isaaclab/bin/activate
```

**Test 1: Create Empty Scene**
```bash
./isaaclab.sh -p scripts/tutorials/00_sim/create_empty.py
```

**Test 2: Train Ant Robot (Simple)**
```bash
./isaaclab.sh -p scripts/reinforcement_learning/rsl_rl/train.py \
    --task=Isaac-Ant-v0 \
    --headless
```

**Test 3: Train Anymal Robot (Advanced)**
```bash
./isaaclab.sh -p scripts/reinforcement_learning/rsl_rl/train.py \
    --task=Isaac-Velocity-Rough-Anymal-C-v0 \
    --headless
```

## 📁 Installation Structure

After installation, you'll have:

```
~/workspace/
├── isaac-sim/              # Symlink to Isaac Sim
├── isaacsim-5.1.0/        # Isaac Sim installation
├── IsaacLab/              # Isaac Lab repository
│   └── env_isaaclab/      # Python virtual environment
└── isaac-sim-lab-installer/  # This repository
```

## 🎮 Running Isaac Lab

Always activate the virtual environment before running Isaac Lab:

```bash
cd ~/workspace/IsaacLab
source env_isaaclab/bin/activate
```

**List available environments:**
```bash
./isaaclab.sh -p scripts/environments/list_envs.py
```

**Run tutorials:**
```bash
./isaaclab.sh -p scripts/tutorials/00_sim/create_empty.py
./isaaclab.sh -p scripts/tutorials/01_assets/run_articulation.py
```

**Run your custom scripts:**
```bash
./isaaclab.sh -p /path/to/your_script.py
```

**Train with custom parameters:**
```bash
./isaaclab.sh -p scripts/reinforcement_learning/rsl_rl/train.py \
    --task=Isaac-Cartpole-v0 \
    --headless \
    --num_envs 4096
```

## 🔧 Configuration

### Change Installation Location

Edit these variables in the scripts:

**`install_isaac_sim.sh`:**
```bash
WORKSPACE_DIR="${HOME}/workspace"
ISAAC_SIM_VERSION="5.1.0"
```

**`install_isaac_lab.sh`:**
```bash
WORKSPACE_DIR="${HOME}/workspace"
ISAAC_LAB_BRANCH="main"          # or "v2.3.0" for stable
PYTHON_VERSION="3.11"
```

## 🐛 Troubleshooting

### `ModuleNotFoundError: No module named 'isaaclab'`

Activate the virtual environment:
```bash
cd ~/workspace/IsaacLab
source env_isaaclab/bin/activate
```

### `Python 3.11 not found`

The `uv` package manager downloads Python 3.11 automatically. No action needed.

### `Isaac Sim not found`

Install Isaac Sim first:
```bash
./install_isaac_sim.sh
```

### Low Disk Space

Check available space:
```bash
df -h ~
```

You need:
- 10GB for Isaac Sim download
- 5GB for Isaac Lab
- 35GB total recommended

### GLIBC Version Error

You need Ubuntu 22.04+ or equivalent:
```bash
lsb_release -a  # Check your version
```

## 📚 Resources

- **Isaac Sim Docs**: https://docs.isaacsim.omniverse.nvidia.com/5.1.0/
- **Isaac Lab Docs**: https://isaac-sim.github.io/IsaacLab/
- **Isaac Lab GitHub**: https://github.com/isaac-sim/IsaacLab
- **Tutorials**: https://isaac-sim.github.io/IsaacLab/main/source/tutorials/

## 🤝 Contributing

Contributions welcome! Feel free to:
1. Fork this repository
2. Create a feature branch
3. Submit a Pull Request

## 📝 License

MIT License - See [LICENSE](LICENSE) file for details.

## ⚠️ Disclaimer

This is an unofficial installation tool. Isaac Sim and Isaac Lab are products of NVIDIA Corporation.

## 📊 Version Information

- **Isaac Sim**: 5.1.0
- **Isaac Lab**: main branch (latest)
- **Python**: 3.11
- **Tested On**: Ubuntu 22.04 LTS

---

**Star ⭐ this repository if it helped you!**

Questions? Open a [GitHub Issue](https://github.com/robosmiths/isaac-sim-lab-installer/issues).
