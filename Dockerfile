# choose an appropriate base image for your algorithm.
FROM cellprofiler/cellprofiler:4.2.6

# docker files start running from the point that got changed. since our code files will tend to change alot,
# we don't want things like pulling the base docker image and downloading the requirements.txt file to happen everytime.
# hence we keep these things at the top

# Packages versions
ENV CUDA_VERSION=10.2.89 \ 
    CUDA_PKG_VERSION=10-2=10.2.89-1 \
    NCCL_VERSION=2.5.6 \
    CUDNN_VERSION=7.6.5.32

# BASE
RUN apt-get update -y && \
    apt-get install -y --no-install-recommends gnupg2 curl ca-certificates && \
    apt-key adv --fetch-keys https://developer.download.nvidia.com/compute/cuda/repos/ubuntu1804/x86_64/3bf863cc.pub && \
    apt-key adv --fetch-keys https://developer.download.nvidia.com/compute/machine-learning/repos/ubuntu1804/x86_64/7fa2af80.pub && \
    # wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu1804/x86_64/cuda-keyring_1.0-1_all.deb && \
    # dpkg -i cuda-keyring_1.0-1_all.deb && \
    echo "deb https://developer.download.nvidia.com/compute/cuda/repos/ubuntu1804/x86_64 /" > /etc/apt/sources.list.d/cuda.list && \
    echo "deb https://developer.download.nvidia.com/compute/machine-learning/repos/ubuntu1804/x86_64 /" > /etc/apt/sources.list.d/nvidia-ml.list && \
    apt-get purge --autoremove -y curl && \
    rm -rf /var/lib/apt/lists/*

# RUNTIME CUDA
RUN apt-get update -y && \
    apt-get install -y --no-install-recommends cuda-cudart-$CUDA_PKG_VERSION cuda-compat-10-2 \
                                               cuda-libraries-$CUDA_PKG_VERSION cuda-nvtx-$CUDA_PKG_VERSION libcublas10=10.2.2.89-1 \
                                               libnccl2=$NCCL_VERSION-1+cuda10.2 && \
    ln -s cuda-10.2 /usr/local/cuda && \
    apt-mark hold libnccl2 && \
    rm -rf /var/lib/apt/lists/*

# RUNTIME CUDNN7
RUN apt-get update -y && \
    apt-get install -y --no-install-recommends libcudnn7=$CUDNN_VERSION-1+cuda10.2 && \
    apt-mark hold libcudnn7 && \
    rm -rf /var/lib/apt/lists/*

# Required for nvidia-docker v1
RUN echo "/usr/local/nvidia/lib" >> /etc/ld.so.conf.d/nvidia.conf && \
    echo "/usr/local/nvidia/lib64" >> /etc/ld.so.conf.d/nvidia.conf

ENV PATH=/usr/local/nvidia/bin:/usr/local/cuda/bin:${PATH} \
    LD_LIBRARY_PATH=/usr/local/nvidia/lib:/usr/local/nvidia/lib64

# nvidia-container-runtime
ENV NVIDIA_VISIBLE_DEVICES=all \
    NVIDIA_DRIVER_CAPABILITIES=compute,utility \
    NVIDIA_REQUIRE_CUDA="cuda>=10.2 brand=tesla,driver>=384,driver<385 brand=tesla,driver>=396,driver<397 brand=tesla,driver>=410,driver<411 brand=tesla,driver>=418,driver<419 brand=tesla,driver>=439,driver<441"

RUN pip3 install torch==1.6.0 torchvision==0.7.0

COPY requirements.txt .
RUN pip3 install -r requirements.txt

WORKDIR /app
RUN git clone https://github.com/vqdang/hover_net

RUN mkdir hovernet_model
RUN gdown https://drive.google.com/uc?id=1NUnO4oQRGL-b0fyzlT8LKZzo6KJD0_6X -O hovernet_model/

COPY ./src/ /app/src/

WORKDIR /app/src

ENTRYPOINT ["python", "app.py"]
# ENTRYPOINT ["bash"]

# CMD ["--codido", "False"]
# TODO: or if you have additional args:
# CMD ["--codido", "False", "--arg1", "val1", "--arg2", "val2", etc]