
#!/bin/bash

# This file will be sourced in init.sh

# https://raw.githubusercontent.com/ai-dock/comfyui/main/config/provisioning/default.sh

DEFAULT_WORKFLOW="https://raw.githubusercontent.com/ai-dock/comfyui/main/config/workflows/flux-comfyui-example.json"

APT_PACKAGES=(
    #"package-1"
    #"package-2"
)

PIP_PACKAGES=(
    #"package-1"
    #"package-2"
)

NODES=(
"https://github.com/jags111/efficiency-nodes-comfyui"
"https://github.com/city96/ComfyUI-GGUF"
"https://github.com/Fannovel16/comfyui_controlnet_aux"
"https://github.com/jags111/efficiency-nodes-comfyui"
"https://github.com/ltdrdata/ComfyUI-Impact-Pack"
"https://github.com/ltdrdata/ComfyUI-Inspire-Pack"
"https://github.com/WASasquatch/was-node-suite-comfyui"
"https://github.com/crystian/ComfyUI-Crystools"
"https://github.com/adieyal/comfyui-dynamicprompts"
"https://github.com/SeargeDP/ComfyUI_Searge_LLM?tab=readme-ov-file#potential-problems"
"https://github.com/dagthomas/comfyui_dagthomas"
)

# Updated model arrays to use associative array format for custom filenames
declare -A CHECKPOINT_MODELS=(
    # ["url"]="custom_filename"
)

declare -A CLIP_MODELS=(
    ["https://huggingface.co/city96/t5-v1_1-xxl-encoder-gguf/resolve/main/t5-v1_1-xxl-encoder-Q8_0.gguf"]="t5-encoder.gguf"
    ["https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/clip_l.safetensors"]="clip-large.safetensors"
)

declare -A UNET_MODELS=(
    # ["url"]="custom_filename"
)

declare -A VAE_MODELS=(
    # ["url"]="custom_filename"
)

declare -A LORA_MODELS=(
    ["https://huggingface.co/Aitrepreneur/FLX/resolve/main/FLUX-dev-lora-AntiBlur.safetensors"]="antiblur-lora.safetensors"
    ["https://huggingface.co/alimama-creative/FLUX.1-Turbo-Alpha/resolve/main/diffusion_pytorch_model.safetensors"]="turbo-alpha.safetensors"
    ["https://civitai.com/api/download/models/917520?type=Model&format=SafeTensor"]="civitai-model.safetensors"
    ["https://civitai.com/api/download/models/862095?type=Model&format=SafeTensor&size=pruned&fp=fp8"]="Acorn_FLUX_V11_Hyper_8-Step.safetensor"
)

declare -A ESRGAN_MODELS=(
    ["https://huggingface.co/ai-forever/Real-ESRGAN/resolve/main/RealESRGAN_x4.pth"]="real-esrgan-x4.pth"
    ["https://huggingface.co/FacehugmanIII/4x_foolhardy_Remacri/resolve/main/4x_foolhardy_Remacri.pth"]="remacri-4x.pth"
    ["https://huggingface.co/Akumetsu971/SD_Anime_Futuristic_Armor/resolve/main/4x_NMKD-Siax_200k.pth"]="anime-4x.pth"
)

declare -A CONTROLNET_MODELS=(
    ["https://huggingface.co/Aitrepreneur/FLX/resolve/main/Shakker-LabsFLUX.1-dev-ControlNet-Union-Pro.safetensors"]="controlnet-union-pro.safetensors"
)

### DO NOT EDIT BELOW HERE UNLESS YOU KNOW WHAT YOU ARE DOING ###

function provisioning_start() {
    if [[ ! -d /opt/environments/python ]]; then 
        export MAMBA_BASE=true
    fi
    source /opt/ai-dock/etc/environment.sh
    source /opt/ai-dock/bin/venv-set.sh comfyui

    # Get licensed models if HF_TOKEN set & valid
    if provisioning_has_valid_hf_token; then
        UNET_MODELS["https://huggingface.co/city96/FLUX.1-dev-gguf/resolve/main/flux1-dev-Q8_0.gguf"]="flux1-dev-q8.gguf"
        VAE_MODELS["https://huggingface.co/black-forest-labs/FLUX.1-dev/resolve/main/ae.safetensors"]="flux1-dev-vae.safetensors"
    else
        UNET_MODELS["https://huggingface.co/black-forest-labs/FLUX.1-schnell/resolve/main/flux1-schnell.safetensors"]="flux1-schnell.safetensors"
        VAE_MODELS["https://huggingface.co/black-forest-labs/FLUX.1-schnell/resolve/main/ae.safetensors"]="flux1-schnell-vae.safetensors"
        sed -i 's/flux1-dev\.safetensors/flux1-schnell.safetensors/g' /opt/ComfyUI/web/scripts/defaultGraph.js
    fi

    provisioning_print_header
    provisioning_get_apt_packages
    provisioning_get_default_workflow
    provisioning_get_nodes
    provisioning_get_pip_packages
    
    # Start all downloads in parallel
    start_parallel_downloads
    
    provisioning_print_end
}

function pip_install() {
    if [[ -z $MAMBA_BASE ]]; then
        "$COMFYUI_VENV_PIP" install --no-cache-dir "$@"
    else
        micromamba run -n comfyui pip install --no-cache-dir "$@"
    fi
}

function provisioning_get_apt_packages() {
    if [[ -n $APT_PACKAGES ]]; then
        sudo $APT_INSTALL ${APT_PACKAGES[@]}
    fi
}

function provisioning_get_pip_packages() {
    if [[ -n $PIP_PACKAGES ]]; then
        pip_install ${PIP_PACKAGES[@]}
    fi
}

function provisioning_get_nodes() {
    for repo in "${NODES[@]}"; do
        dir="${repo##*/}"
        path="/opt/ComfyUI/custom_nodes/${dir}"
        requirements="${path}/requirements.txt"
        if [[ -d $path ]]; then
            if [[ ${AUTO_UPDATE,,} != "false" ]]; then
                printf "Downloading node: %s...\n" "${repo}"
                ( cd "$path" && git pull )
                if [[ -e $requirements ]]; then
                    pip_install -r "$requirements"
                fi
            fi
        else
            printf "Downloading node: %s...\n" "${repo}"
            git clone "${repo}" "${path}" --recursive
            if [[ -e $requirements ]]; then
                pip_install -r "${requirements}"
            fi
        fi
    done
}

function provisioning_get_default_workflow() {
    if [[ -n $DEFAULT_WORKFLOW ]]; then
        workflow_json=$(curl -s "$DEFAULT_WORKFLOW")
        if [[ -n $workflow_json ]]; then
            echo "export const defaultGraph = $workflow_json;" > /opt/ComfyUI/web/scripts/defaultGraph.js
        fi
    fi
}

function start_parallel_downloads() {
    local pids=()
    local total_downloads=0
    local completed_downloads=0
    
    # Create a temporary directory for download status files
    local tmp_dir="/tmp/download_status"
    rm -rf "$tmp_dir"
    mkdir -p "$tmp_dir"
    
    # Function to download a category of models
    download_category() {
        local dir="$1"
        local model_array="$2"
        local category_name="$3"
        
        mkdir -p "$dir"
        eval "declare -A models=${model_array#*=}"
        
        for url in "${!models[@]}"; do
            local filename="${models[$url]}"
            local status_file="${tmp_dir}/${category_name}_${filename//\//_}"
            
            # Start download in background
            (
                echo "0" > "$status_file"
                if provisioning_download "${url}" "${dir}" "${filename}" "$status_file"; then
                    echo "100" > "$status_file"
                    echo "Completed: ${category_name}/${filename}"
                else
                    echo "Failed: ${category_name}/${filename}"
                fi
            ) &
            pids+=($!)
            ((total_downloads++))
        done
    }
    
    # Start all downloads
    local model_types=(
        "checkpoint|CHECKPOINT_MODELS"
        "unet|UNET_MODELS"
        "lora|LORA_MODELS"
        "controlnet|CONTROLNET_MODELS"
        "vae|VAE_MODELS"
        "clip|CLIP_MODELS"
        "esrgan|ESRGAN_MODELS"
    )
    
    for type_info in "${model_types[@]}"; do
        IFS="|" read -r folder var_name <<< "$type_info"
        if [[ -v "$var_name" ]]; then
            download_category "${WORKSPACE}/storage/stable_diffusion/models/${folder}" "$(declare -p $var_name)" "$folder"
        fi
    done
    
    # Monitor progress
    echo "Starting $total_downloads downloads in parallel..."
    
    # Wait for all downloads to complete while showing progress
    while [ ${#pids[@]} -gt 0 ]; do
        for pid in "${pids[@]}"; do
            if ! kill -0 $pid 2>/dev/null; then
                # Process completed
                pids=("${pids[@]/$pid}")
                ((completed_downloads++))
                printf "\rCompleted: $completed_downloads/$total_downloads downloads"
            fi
        done
        sleep 1
    done
    
    echo -e "\nAll downloads completed!"
    
    # Cleanup
    rm -rf "$tmp_dir"
}

function provisioning_download() {
    local url="$1"
    local dir="$2"
    local filename="$3"
    local status_file="$4"
    local log_file="/tmp/download_${filename}.log"
    local max_retries=3
    local retry_count=0
    local success=false

    echo "Starting download: $filename from $url" | tee -a "$log_file"
    
    # Create directory if it doesn't exist
    mkdir -p "$dir"

    while [ $retry_count -lt $max_retries ] && [ "$success" = false ]; do
        if [ $retry_count -gt 0 ]; then
            echo "Retry attempt $retry_count for $filename" | tee -a "$log_file"
            sleep 5
        fi

        if [[ -n $HF_TOKEN && $url =~ ^https://([a-zA-Z0-9_-]+\.)?huggingface\.co(/|$|\?) ]]; then
            echo "Using Hugging Face authentication for $filename" | tee -a "$log_file"
            wget --header="Authorization: Bearer $HF_TOKEN" \
                 --tries=3 \
                 --timeout=30 \
                 --retry-connrefused \
                 --no-verbose \
                 -c -O "${dir}/${filename}" \
                 "$url" 2>> "$log_file"
        
        elif [[ -n $CIVITAI_TOKEN && $url =~ ^https://([a-zA-Z0-9_-]+\.)?civitai\.com(/|$|\?) ]]; then
            echo "Using Civitai authentication for $filename" | tee -a "$log_file"
            local download_url
            if [[ $url == *"?"* ]]; then
                download_url="${url}&token=${CIVITAI_TOKEN}"
            else
                download_url="${url}?token=${CIVITAI_TOKEN}"
            fi
            echo "Constructed Civitai URL (token hidden)" | tee -a "$log_file"
            wget --tries=3 \
                 --timeout=30 \
                 --retry-connrefused \
                 --no-verbose \
                 -c -O "${dir}/${filename}" \
                 "$download_url" 2>> "$log_file"
        
        else
            echo "No authentication required for $filename" | tee -a "$log_file"
            wget --tries=3 \
                 --timeout=30 \
                 --retry-connrefused \
                 --no-verbose \
                 -c -O "${dir}/${filename}" \
                 "$url" 2>> "$log_file"
        fi

        if [ $? -eq 0 ] && [ -f "${dir}/${filename}" ] && [ -s "${dir}/${filename}" ]; then
            success=true
            echo "Successfully downloaded $filename" | tee -a "$log_file"
        else
            ((retry_count++))
            echo "Download failed for $filename (attempt $retry_count of $max_retries)" | tee -a "$log_file"
        fi
    done

    if [ "$success" = true ]; then
        echo "100" > "$status_file"
        return 0
    else
        echo "Failed to download $filename after $max_retries attempts" | tee -a "$log_file"
        echo "0" > "$status_file"
        return 1
    fi
}

function start_parallel_downloads() {
    local pids=()
    local total_downloads=0
    local completed_downloads=0
    local failed_downloads=0
    local tmp_dir="/tmp/download_status"
    
    # Cleanup previous status files
    rm -rf "$tmp_dir"
    mkdir -p "$tmp_dir"
    
    # Maximum concurrent downloads
    local max_concurrent=5
    local current_downloads=0
    
    download_category() {
        local dir="$1"
        local model_array="$2"
        local category_name="$3"
        
        mkdir -p "$dir"
        eval "declare -A models=${model_array#*=}"
        
        for url in "${!models[@]}"; do
            local filename="${models[$url]}"
            local status_file="${tmp_dir}/${category_name}_${filename//\//_}"
            
            # Wait if we've reached max concurrent downloads
            while [ $current_downloads -ge $max_concurrent ]; do
                for pid in "${pids[@]}"; do
                    if ! kill -0 $pid 2>/dev/null; then
                        pids=("${pids[@]/$pid}")
                        ((current_downloads--))
                        ((completed_downloads++))
                        printf "\rCompleted: %d/%d downloads (Failed: %d)" "$completed_downloads" "$total_downloads" "$failed_downloads"
                    fi
                done
                sleep 1
            done
            
            # Start new download
            (
                if provisioning_download "${url}" "${dir}" "${filename}" "$status_file"; then
                    echo "Completed: ${category_name}/${filename}"
                else
                    echo "Failed: ${category_name}/${filename}"
                    ((failed_downloads++))
                fi
            ) &
            
            pids+=($!)
            ((current_downloads++))
            ((total_downloads++))
        done
    }
    
    # Start downloads by category
    echo "Starting downloads..."
    local model_types=(
        "checkpoint|CHECKPOINT_MODELS"
        "unet|UNET_MODELS"
        "lora|LORA_MODELS"
        "controlnet|CONTROLNET_MODELS"
        "vae|VAE_MODELS"
        "clip|CLIP_MODELS"
        "esrgan|ESRGAN_MODELS"
    )
    
    for type_info in "${model_types[@]}"; do
        IFS="|" read -r folder var_name <<< "$type_info"
        if [[ -v "$var_name" ]]; then
            download_category "${WORKSPACE}/storage/stable_diffusion/models/${folder}" "$(declare -p $var_name)" "$folder"
        fi
    done
    
    # Wait for remaining downloads
    echo "Waiting for downloads to complete..."
    while [ ${#pids[@]} -gt 0 ]; do
        for pid in "${pids[@]}"; do
            if ! kill -0 $pid 2>/dev/null; then
                pids=("${pids[@]/$pid}")
                ((completed_downloads++))
                printf "\rCompleted: %d/%d downloads (Failed: %d)" "$completed_downloads" "$total_downloads" "$failed_downloads"
            fi
        done
        sleep 1
    done
    
    echo -e "\n\nDownload Summary:"
    echo "Total downloads: $total_downloads"
    echo "Successful downloads: $((completed_downloads - failed_downloads))"
    echo "Failed downloads: $failed_downloads"
    
    # Show failed downloads from logs
    echo -e "\nFailed downloads detail:"
    for log in /tmp/download_*.log; do
        if grep -q "Failed to download" "$log"; then
            echo "- $(basename "$log" .log)"
            tail -n 3 "$log"
        fi
    done
    
    # Cleanup
    rm -rf "$tmp_dir"
    
    # Return failure if any downloads failed
    [ $failed_downloads -eq 0 ]
}

function provisioning_print_header() {
    printf "\n##############################################\n#                                            #\n#          Provisioning container            #\n#                                            #\n#         This will take some time           #\n#                                            #\n# Your container will be ready on completion #\n#                                            #\n##############################################\n\n"
    if [[ $DISK_GB_ALLOCATED -lt $DISK_GB_REQUIRED ]]; then
        printf "WARNING: Your allocated disk size (%sGB) is below the recommended %sGB - Some models will not be downloaded\n" "$DISK_GB_ALLOCATED" "$DISK_GB_REQUIRED"
    fi
}

function provisioning_print_end() {
    printf "\nProvisioning complete:  Web UI will start now\n\n"
}

function provisioning_has_valid_hf_token() {
    [[ -n "$HF_TOKEN" ]] || return 1
    url="https://huggingface.co/api/whoami-v2"
    
    response=$(curl -o /dev/null -s -w "%{http_code}" -X GET "$url" \
        -H "Authorization: Bearer $HF_TOKEN" \
        -H "Content-Type: application/json")
    
    # Check if the token is valid
    if [ "$response" -eq 200 ]; then
        return 0
    else
        return 1
    fi
}

function provisioning_has_valid_civitai_token() {
    [[ -n "$CIVITAI_TOKEN" ]] || return 1
    url="https://civitai.com/api/v1/models?hidden=1&limit=1"
    
    response=$(curl -o /dev/null -s -w "%{http_code}" -X GET "$url" \
        -H "Authorization: Bearer $CIVITAI_TOKEN" \
        -H "Content-Type: application/json")
    
    # Check if the token is valid
    if [ "$response" -eq 200 ]; then
        return 0
    else
        return 1
    fi
}

provisioning_start
