#!/bin/bash

# Base name of the environment
ENV_BASE_NAME="ai_env"
ERROR_LOG="errors.log"
ENV_YAML_FILE="environment.yaml"
HF_TOKEN=".env"
GITHUB_TOKEN=".env"

> $ERROR_LOG

log_error() {
    echo "$1" >> $ERROR_LOG
}

list_existing_envs() {
    conda env list | grep "^${ENV_BASE_NAME}" | awk '{print $1}' | grep "^${ENV_BASE_NAME}"
}

generate_env_name() {
    echo -e "Generating unique environment name..."
    local count=1
    local new_env_name=$ENV_BASE_NAME
    while [[ -n "$(conda env list | grep "^${new_env_name}")" ]]; do
        count=$((count+1))
        new_env_name="${ENV_BASE_NAME}_${count}"
    done
    echo "$new_env_name"
}

display_env_options() {
    local envs
    envs=$(list_existing_envs)

    if [[ -z "$envs" ]]; then
        echo "No existing environments found."
        return 1
    else
        echo "The following environments exist:"
        echo "$envs" | awk '{print NR ". " $0}'

        echo "$(( $(echo "$envs" | wc -l) + 1 )). Create a new environment"
        return 0
    fi
}

prompt_env_selection() {
    local envs
    envs=$(list_existing_envs)

    local choice
    local env_count=$(echo "$envs" | wc -l)

    while true; do
        read -p "Select an environment (enter the number): " choice

        if [[ "$choice" =~ ^[0-9]+$ && "$choice" -ge 1 && "$choice" -le $(( env_count + 1 )) ]]; then
            if [[ "$choice" -le "$env_count" ]]; then
                selected_env=$(echo "$envs" | sed -n "${choice}p")
                echo "$selected_env"
            else
                echo "Creating a new environment..."
                echo $(generate_env_name)
            fi
            break
        else
            echo "Invalid selection. Please enter a valid number."
        fi
    done
}

# Step 1: Detect the OS
echo -e "\n[AI Matrx Step 1] Detecting OS type..."
OS_TYPE=$(uname)

# Step 2: List and display available environments and handle selection/creation
echo -e "\n[AI Matrx Step 2] Listing and displaying environments...\n"
if display_env_options; then
    ENV_NAME=$(prompt_env_selection)
else
    ENV_NAME=$(generate_env_name)
fi

# Step 3: Initialize Conda and create or activate the environment without checks
echo -e "\n[AI Matrx Step 3] Initializing Conda and activating environment: '$ENV_NAME'\n"

eval "$(conda 'shell.bash' 'hook')" || { echo "Failed to initialize Conda"; exit 1; }

if ! conda env list | grep "^${ENV_NAME}" > /dev/null; then
    echo "Conda environment '$ENV_NAME' does not exist. Creating it..."
    conda create -n "$ENV_NAME" python=3.10 -y || { echo "Failed to create Conda environment"; exit 1; }
fi

conda activate "$ENV_NAME" || { echo "Failed to activate Conda environment '$ENV_NAME'"; exit 1; }

# Step 4: Hugging Face CLI: Install and login
echo -e "\n[AI Matrx Step 4] Installing and logging into Hugging Face CLI...\n"
pip install -U "huggingface_hub[cli]" || { log_error "Failed to install Hugging Face CLI"; exit 1; }

# Ensure HF_TOKEN is set
if [[ -z "$HF_TOKEN" ]]; then
    log_error "Hugging Face token (HF_TOKEN) is not set."
    exit 1
fi

huggingface-cli login --token "$HF_TOKEN" || { log_error "Failed to log in to Hugging Face CLI"; exit 1; }

if [ $? -ne 0 ]; then
    echo -e "Hugging Face login failed. Some functionalities may not work. Please log in manually.\n"
    log_error "Hugging Face login failed. Some functionalities may not work. Please log in manually."
else
    echo "Hugging Face login successful."
fi

# Step 5: Install remaining utilities depending on the operating system
if [[ "$OS_TYPE" == "Linux" ]]; then
    echo -e "\n[AI Matrx Step 5] Detected Linux system, installing essential Linux utilities..."
    sudo apt update || { log_error "Failed to update package list"; exit 1; }
    sudo apt install -y \
        curl \
        wget \
        git \
        nano \
        build-essential \
        htop \
        unzip \
        ffmpeg \
        tmux \
        python3-pip \
        libgl1-mesa-glx \
        software-properties-common || log_error "Failed to install basic utilities"
elif [[ "$OS_TYPE" == "MINGW"* || "$OS_TYPE" == "MSYS"* ]]; then
    echo "Detected Windows system, skipping Linux utility installation..."
else
    echo "Unknown system type: $OS_TYPE"
    log_error "Unknown system type: $OS_TYPE"
    exit 1
fi

# Step 6: Install dependencies from the environment.yaml file
echo -e "\n[AI Matrx Step 6] Installing dependencies from $ENV_YAML_FILE...\n"
conda env update --file $ENV_YAML_FILE --prune || log_error "Failed to update environment with $ENV_YAML_FILE"

# Step 7: Create necessary directories if they don't already exist
echo -e "\n[AI Matrx Step 7] Checking and creating directories...\n"
directories=(ComfyUI LivePortrait SillyTavern text-generation-webui insightface CogVideo OneDiff resources models)

for dir in "${directories[@]}"; do
    if [ ! -d "$dir" ]; then
        echo "Creating directory '$dir'..."
        mkdir -p "$dir" || log_error "Failed to create directory '$dir'"
    else
        echo "Directory '$dir' already exists. Skipping creation."
    fi
done

# Step 8: Clone GitHub repositories into appropriate directories if they don't already exist
echo -e "\n[AI Matrx Step 8] Cloning GitHub repositories...\n"
repos=(
    "https://$GITHUB_TOKEN@github.com/comfyanonymous/ComfyUI.git ComfyUI"
    "https://$GITHUB_TOKEN@github.com/KwaiVGI/LivePortrait.git LivePortrait"
    "https://$GITHUB_TOKEN@github.com/SillyTavern/SillyTavern.git SillyTavern"
    "https://$GITHUB_TOKEN@github.com/oobabooga/text-generation-webui.git text-generation-webui"
    "https://$GITHUB_TOKEN@github.com/deepinsight/insightface.git insightface"
    "https://$GITHUB_TOKEN@github.com/THUDM/CogVideo.git CogVideo"
    "https://$GITHUB_TOKEN@github.com/siliconflow/onediff.git OneDiff"
    "https://$GITHUB_TOKEN@github.com/fastai/fastai.git FastAI"
    "https://$GITHUB_TOKEN@github.com/armanisadeghi/image.git resources"
)

for repo in "${repos[@]}"; do
    repo_url=$(echo $repo | awk '{print $1}')
    repo_dir=$(echo $repo | awk '{print $2}')

    if [ ! -d "$repo_dir/.git" ]; then
        echo "Cloning $repo_url into $repo_dir..."
        git clone $repo_url $repo_dir || log_error "Failed to clone $repo_url"
    else
        echo "Repository $repo_dir already exists. Skipping clone."
    fi
done

# Step 9: Download models from Hugging Face into the models directory
echo -e "\n[AI Matrx Step 9] Checking for existing models and downloading if necessary...\n"
cd models || { log_error "Failed to switch to models directory"; exit 1; }

# Download Juggernaut-XL-v9 model from Hugging Face
if [ ! -d "Juggernaut-XL-v9" ]; then
    echo "Downloading Juggernaut-XL-v9..."
    huggingface-cli download RunDiffusion/Juggernaut-XL-v9 --repo-type model --local-dir . || log_error "Failed to download Juggernaut-XL-v9"
else
    echo -e "Model Juggernaut-XL-v9 already exists. Skipping download.\n"
fi

# Download RealVisXL_V4.0 model from Hugging Face
if [ ! -d "RealVisXL_V4.0" ]; then
    echo "Downloading RealVisXL_V4.0..."
    huggingface-cli download SG161222/RealVisXL_V4.0 --repo-type model --local-dir . || log_error "Failed to download RealVisXL_V4.0"
else
    echo -e "Model RealVisXL_V4.0 already exists. Skipping download.\n"
fi

# Step 10: Check for errors and display summary
cd ..
if [ -s $ERROR_LOG ]; then
    echo -e "\n[AI Matrx Step 10] Errors encountered during setup:\n"
    cat $ERROR_LOG
    echo "Please review the errors and resolve them."
else
    echo -e "\n[AI Matrx Step 10] Congratulations! Environment setup completed successfully with no errors.\n"
fi
