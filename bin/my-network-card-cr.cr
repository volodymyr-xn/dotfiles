module PCIDevicesInfo
  NETWORK_DEVICE_NAME_REGEX = /[Nn]et/

  # Get list of all PCI devices splited into new lines
  def self.all
    `lspci`.split("\n")
  end

  def self.network_devices
    # Select those that match network device name
    all.select { |e| e.match(NETWORK_DEVICE_NAME_REGEX) }
  end

  # Get only network devices
  def self.network_devices_details
    network_devices
      # Map ids of devices
      .map { |e|
        e.split(/\s/).first
      }
      # Use this ids to obtain device info
      .map { |e|
        `lspci -ks #{e}` + "\n"
      }
  end

  def self.network_devices_details_full
    `lshw -class network`
  end
end

puts PCIDevicesInfo.network_devices_details
