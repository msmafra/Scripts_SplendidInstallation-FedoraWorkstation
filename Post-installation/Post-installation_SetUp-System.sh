#!/bin/bash

# "Splendid installation" scripts for Fedora Workstation
# Copyright (C) 2021 Mislav Volaj
# Read full copyright notices by viewing the source code of the main menu script or by running it



Configure_KernelModules() {
    echo "Configuring kernel modules..."

    # Importing kernel modules configuration or configuring kernel modules
    if [[ -f "$SETTINGSDIRECTORY"/blacklist.conf ]]
    then
        sudo cp "$SETTINGSDIRECTORY"/blacklist.conf /etc/modprobe.d/
    else
        # Disabling wrong drivers
        sudo sh -c "printf '%s\n' \
            'blacklist i2c_hid' \
            'blacklist psmouse' > /etc/modprobe.d/blacklist.conf"
    fi

    # Importing Intel chipset features configuration or configuring Intel chipset features
    if [[ -f "$SETTINGSDIRECTORY"/i915.conf ]]
    then
        sudo cp "$SETTINGSDIRECTORY"/i915.conf /etc/modprobe.d/
    else
        # Enabling Intel chipset features
        sudo sh -c "printf '%s\n' \
            'options i915 fastboot=1 modeset=1' > /etc/modprobe.d/i915.conf"
    fi

    echo "Kernel modules configuration script completed..."
}

Configure_ZramSwap() {
    echo "Configuring zram swap space..."

    # Selecting zram configuration method
    read -p "Select a zram configuration method to use: zram-generator, udev rule, zramctl: (g/u/c/ anything else to skip): "

    if [[ $REPLY =~ ^[Gg]$ ]]
    then
        # Importing zram swap space configuration or configuring zram swap space
        if [[ -f "$SETTINGSDIRECTORY"/zram-generator.conf ]]
        then
            sudo cp "$SETTINGSDIRECTORY"/zram-generator.conf /etc/systemd/
        else
            read -p "Type a compression algorithm to be used by zram: (lzo, lzo-rle, lz4, lz4hc, zstd) (default: lzo-rle): " ZRAMALGORITHM
            read -p "Type a highest ammount of RAM allowed to be used by zram: (default: 4096): " ZRAMSIZE
            read -p "Type a fraction of RAM to be used by zram: (default: 0.5): " ZRAMFRACTION

            # Creating zram-generator configuration file
            sudo sh -c "printf '%s\n' \
                '[zram0]' \
                'compression-algorithm = $ZRAMALGORITHM' \
                'max-zram-size = $ZRAMSIZE' \
                'zram-fraction = $ZRAMFRACTION' > /etc/systemd/zram-generator.conf"
        fi

        # Enabling zram-generator configuration method
        sudo systemctl enable swap-create@zram0.service

        # Applying modified zram swap space configuration
        read -p "Would you like to apply modified zram swap space configuration immediately? (y/ anything else to skip): "

        if [[ $REPLY =~ ^[Yy]$ ]]
        then
            sudo systemctl restart swap-create@zram0.service

            echo "Modified zram swap space configuration immediate application script completed!"
        else
            echo "Modified zram swap space configuration will be applied while booting!"
        fi
    elif [[ $REPLY =~ ^[Uu]$ ]]
    then
        # Creating a configuration file to load zram kernel module while booting
        sudo sh -c "printf '%s\n' \
            'zram' > /etc/modules-load.d/zram.conf"

        # Creating a configuration file to initialize zram devices
        sudo sh -c "printf '%s\n' \
            'options zram num_devices=1' > /etc/modprobe.d/zram.conf"

        # Importing zram swap space configuration or configuring zram swap space
        if [[ -f "$SETTINGSDIRECTORY"/99-zram.rules ]]
        then
            sudo cp "$SETTINGSDIRECTORY"/99-zram.rules /etc/udev/rules.d/
        else
            # Creating zram swap space udev rule
            read -p "Type a compression algorithm to be used by zram: (lzo, lzo-rle, lz4, lz4hc, zstd) (default: lzo-rle): " ZRAMALGORITHM
            read -p "Type an ammount of RAM to be used by zram: (default: 4096): " ZRAMSIZE

            sudo sh -c "printf '%s\n' \
                'KERNEL==\"zram0\", ATTR{comp_agorithm}=\"$ZRAMALGORITHM\" ATTR{disksize}=\"$ZRAMSIZE''MiB\", RUN=\"/usr/bin/mkswap /dev/zram0\", TAG+=\"systemd\"' > /etc/udev/rules.d/99-zram.rules"
        fi

        # Adding zram devices to file systems table
        sudo sh -c "printf '%s\n' \
            '/dev/zram0 none swap defaults 0 0' >> /etc/fstab"

        # Disabling zram-generator configuration method
        sudo systemclt disable swap-create@zram0.service

        echo "Modified zram swap space configuration will be applied while booting!"
    elif [[ $REPLY =~ ^[Cc]$ ]]
    then
        # Configuring zram swap space
        read -p "Type a compression algorithm to be used by zram: (lzo, lzo-rle, lz4, lz4hc, zstd) (default: lzo-rle): " ZRAMALGORITHM
        read -p "Type an ammount of RAM to be used by zram: (default: 4096): " ZRAMSIZE

        sudo zramctl --algorithm $ZRAMALGORITHM --size "$ZRAMSIZE"MiB zram0

        echo "Temporary modified zram swap space configuration immediate application script completed!"
    else
        echo "Configuring zram swap space skipped!"
    fi

    echo "Zram swap space configuration script completed!"
}

Configure_Hibernation() {
    echo "Configuring hibernation..."

    # Importing hibernating configuration or configuring hibernating
    if [[ -f "$SETTINGSDIRECTORY"/sleep.conf ]]
    then
        sudo cp "$SETTINGSDIRECTORY"/sleep.conf /etc/systemd/
    else
        # Enabling hibernating
        sudo sed --in-place 's/#AllowHibernation=.*/AllowHibernation=yes/' /etc/systemd/sleep.conf
        sudo sed --in-place 's/#HibernateMode=.*/HibernateMode=platform shutdown/' /etc/systemd/sleep.conf
    fi

    # Importing resuming configuration or configuring resuming
    if [[ -f "$SETTINGSDIRECTORY"/resume.conf ]]
    then
        sudo cp "$SETTINGSDIRECTORY"/resume.conf /etc/dracut.conf.d/
    else
        # Enabling resuming
        sudo sh -c "printf '%s\n' \
            'add_dracutmodules+=\" resume \"' > /etc/dracut.conf.d/resume.conf"
    fi

    echo "Hibernation configuration script completed!"
}

Configure_FileSystems() {
    echo "Configuring file systems..."

    # Configuring mounting /var partition with restrictions
    read -p "Would you like to mount \"/var\" partition with restrictions? (y/ anything else to skip): "

    if [[ $REPLY =~ ^[Yy]$ ]]
    then
        read -p "Will you be using Flatpak containerised software? (y/n) (default: y): "

        if [[ $REPLY =~ ^[Yy]$ ]]
        then
            sudo sed --in-place '/\/var/ s/noatime/noatime,nodev,nosuid/' /etc/fstab

            echo "Configuring \"/var\" partition with \"nodev\" and \"nosuid\" restrictions script completed!"

            # Remounting /var partition with restrictions
            read -p "Would you like to remount \"/var\" partition with restrictions immediately? (y/ anything else to skip): "

            if [[ $REPLY =~ ^[Yy]$ ]]
            then
                sudo mount -o remount,nodev,nosuid /var

                echo "Remounted \"/var\" partition with restrictions!"
            else
                echo "\"/var\" partition will be remounted with restrictions while rebooting!"
            fi
        elif [[ $REPLY =~ ^[Nn]$ ]]
        then
            sudo sed --in-place '/\/var/ s/noatime/noatime,nodev,noexec,nosuid/' /etc/fstab

            echo "Configuring \"/var\" partition with \"nodev\", \"noexec\" and \"nosuid\" restrictions script completed!"

            # Remounting /var partition with restrictions
            read -p "Would you like to remount \"/var\" partition with restrictions immediately? (y/ anything else to skip): "

            if [[ $REPLY =~ ^[Yy]$ ]]
            then
                sudo mount -o remount,nodev,noexec,nosuid /var

                echo "Remounted \"/var\" partition with restrictions!"
            else
                echo "\"/var\" partition will be remounted with restrictions while rebooting!"
            fi
        fi
    else
        echo "Mounting \"/var\" partition with restrictions skipped!"
    fi

    # Manually modifying file systems table
    read -p "Would you like to manually modify file systems table? (y/ anything else to skip): "

    if [[ $REPLY =~ ^[Yy]$ ]]
    then
        sudo nano /etc/fstab
    fi

    # Configuring systemd units
    sudo systemctl daemon-reload

    # Importing mounting external file systems configuration or configuring mounting external file systems
    if [[ -f "$SETTINGSDIRECTORY"/mount_options.conf ]]
    then
        sudo cp "$SETTINGSDIRECTORY"/mount_options.conf /etc/udisks2/
    else
        # Writing mounting defaults for external Btrfs file systems
        sudo sh -c "printf '%s\n' \
            '[defaults]' \
            'btrfs_defaults=discard=async,compress-force=zstd:2,noatime,space_cache' > /etc/udisks2/mount_options.conf"
    fi

    echo "File systems configuration script completed!"
}

Write_BootConfiguration() {
    echo "Writing boot configuration..."

    # Creating a list of dependencies of kernel modules and its associated map files
    sudo depmod --all

    # Creating Initial RAM file system (initramfs)
    sudo dracut --regenerate-all --force

    # Writing boot configuration
    sudo grub2-mkconfig --output=/boot/efi/EFI/fedora/grub.cfg

    echo "Boot configuration writing script completed!"
}

Configure_Networking() {
    echo "Configuring networking..."

    # Configuring firewall
    sudo firewall-cmd --set-default-zone=external

    # Importing Domain Name System resolving configuration or configuring Domain Name System resolving
    if [[ -f "$SETTINGSDIRECTORY"/resolved.conf ]]
    then
        sudo cp "$SETTINGSDIRECTORY"/resolved.conf /etc/systemd/
    else
        sudo sed --in-place 's/#DNS=.*/DNS=1.1.1.1 1.0.0.1 2606:4700:4700::1111 2606:4700:4700::1001/' /etc/systemd/resolved.conf
        sudo sed --in-place 's/#FallbackDNS=.*/FallbackDNS=8.8.8.8 8.8.4.4 2001:4860:4860::8888 2001:4860:4860::8844/' /etc/systemd/resolved.conf
    fi

    # Importing OpenVPN server configuration files
    if [[ -d "$SETTINGSDIRECTORY"/VPN ]]
    then
        read -p "Type the username for VPN connections: " "VPNUSERNAME"
        read -p "Type the password for VPN connections: (REMINDER: Escape special characters with a backslash!): " "VPNPASSWORD"

        for VPNCONFIGURATION in "$SETTINGSDIRECTORY"/VPN/*
        do
            nmcli connection import type openvpn file "$VPNCONFIGURATION"
            VPNID=$(basename "$VPNCONFIGURATION")
            nmcli connection modify id "$VPNID" +vpn.data username=$VPNUSERNAME +vpn.secrets password=$VPNPASSWORD
        done
    fi

    echo "Networking configuration script completed!"
}

Configure_Services() {
    echo "Configuring services..."

    # Importing logging history retention configuration or configuring logging history retention time
    if [[ -f "$SETTINGSDIRECTORY"/journald.conf ]]
    then
        sudo cp "$SETTINGSDIRECTORY"/journald.conf /etc/systemd/
    else
        read -p "Type the number of days to retain logging history: " LOGTIME

        sudo sed --in-place 's/#MaxRetentionSec=/MaxRetentionSec='$LOGTIME'day/' /etc/systemd/journald.conf
    fi

    # Importing temporary files retention configuration or configuring temporary files retention time
    if [[ -f "$SETTINGSDIRECTORY"/tmp.conf ]]
    then
        sudo cp "$SETTINGSDIRECTORY"/tmp.conf /usr/lib/tmpfiles.d/
    else
        read -p "Type the number of days to retain temporary files: " TEMPORARYFILESTIME

        sudo sed --in-place 's/tmp 1777 root root .*/tmp 1777 root root '$TEMPORARYFILESTIME'd/' /usr/lib/tmpfiles.d/tmp.conf
        sudo sed --in-place 's/\/var\/tmp 1777 root root .*/\/var\/tmp 1777 root root '$TEMPORARYFILESTIME'd/' /usr/lib/tmpfiles.d/tmp.conf
    fi

    echo "Services configuration script completed!"
}

Install_Nautilus-Thumbnailers() {
    echo "Installing Nautilus thumbnailers..."

    # Importing or installing WebP image format thumbnailer
    if [[ -f "$SETTINGSDIRECTORY"/Nautilus/webp.thumbnailer ]]
    then
        sudo cp "$SETTINGSDIRECTORY"/Nautilus/webp.thumbnailer /usr/share/thumbnailers
    else
        sudo sh -c "printf '%s\n' \
            '[Thumbnailer Entry]' \
            'TryExec=/usr/bin/dwebp' \
            'Exec=/usr/bin/dwebp %i -o %o' \
            'MimeType=image/x-webp;image/webp;' > /usr/share/thumbnailers/webp.thumbnailer"
    fi

    echo "Nautilus thumbnailers installation script completed!"
}



Menu() {
    echo

    PS3="Press 1 to exit, 2 to run all options or 3-10 to select an option to run: "

    select options in "EXIT" "RUN ALL OPTIONS" "Configure kernel modules" "Configure zram swap space" "Configure hibernation" "Configure file systems" "Write boot configuration" "Configure networking" "Configure services" "Install Nautilus thumbnailers"; do
        case "$options" in
            "EXIT" )
                exit 0;;
            "RUN ALL OPTIONS" )
                Configure_KernelModules
                Configure_ZramSwap
                Configure_Hibernation
                Configure_FileSystems
                Write_BootConfiguration
                Configure_Networking
                Configure_Services
                Install_Nautilus-Thumbnailers
                exit 0;;
            "Configure kernel modules" )
                Configure_KernelModules
                Menu;;
            "Configure zram swap space" )
                Configure_ZramSwap
                Menu;;
            "Configure hibernation" )
                Configure_Hibernation
                Menu;;
            "Configure file systems" )
                Configure_FileSystems
                Menu;;
            "Write boot configuration" )
                Write_BootConfiguration
                Menu;;
            "Configure networking" )
                Configure_Networking
                Menu;;
            "Configure services" )
                Configure_Services
                Menu;;
            "Install Nautilus thumbnailers" )
                Install_Nautilus-Thumbnailers
                Menu;;
        esac
    done
}



COLUMNS=1
WORKINGDIRECTORY="$(pwd)/Pre-installation/"
SETTINGSDIRECTORY="$(pwd)/Pre-installation/Settings/System"

Menu
