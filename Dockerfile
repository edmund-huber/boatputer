FROM mkaczanowski/packer-builder-arm:latest

COPY packer/ /build/
WORKDIR /build

CMD ["build", "boatputer.pkr.hcl"]
