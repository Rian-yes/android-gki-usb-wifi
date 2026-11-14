#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <unistd.h>
#include <string.h>
#include <errno.h>
#include <sys/socket.h>
#include <sys/ioctl.h>

#ifndef AF_BLUETOOTH
#define AF_BLUETOOTH 31
#endif
#define BTPROTO_HCI 1
#define HCIDEVUP      _IOW('H', 201, int)
#define HCIDEVDOWN    _IOW('H', 202, int)
#define HCIDEVRESET   _IOW('H', 203, int)
#define HCIGETDEVINFO _IOR('H', 211, int)

/* Scan mode: 0 = none, 1 = iscan, 2 = pscan, 3 = piscan */
#define HCISETSCAN  _IOW('H', 221, int)
#define SCAN_PAGE     0x02
#define SCAN_INQUIRY  0x01

/* Simple pairing mode: 1 = enabled */
#define HCISETSMPAIR _IOW('H', 227, int)

enum {
    HCI_UP,
    HCI_INIT,
    HCI_RUNNING,
    HCI_PSCAN,
    HCI_ISCAN,
    HCI_AUTH,
    HCI_ENCRYPT
};

struct hci_dev_req {
    uint16_t dev_id;
    uint32_t dev_opt;
};

struct bdaddr_t {
    uint8_t b[6];
};

struct hci_dev_info {
    uint16_t dev_id;
    char     name[8];
    struct bdaddr_t bdaddr;
    uint32_t flags;
    uint8_t  type;
    uint8_t  features[8];
    uint32_t pkt_type;
    uint32_t link_policy;
    uint32_t link_mode;
    uint16_t acl_mtu;
    uint16_t acl_pkts;
    uint16_t sco_mtu;
    uint16_t sco_pkts;
    uint32_t stat[10];
};

int main(int argc, char **argv) {
    int dev_id = 0;
    int mode = 1; // 0=down, 1=up, 2=status

    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "-d") == 0 || strcmp(argv[i], "down") == 0) {
            mode = 0;
        } else if (strcmp(argv[i], "-u") == 0 || strcmp(argv[i], "up") == 0) {
            mode = 1;
        } else if (strcmp(argv[i], "-s") == 0 || strcmp(argv[i], "status") == 0) {
            mode = 2;
        } else {
            dev_id = atoi(argv[i]);
        }
    }

    int s = socket(AF_BLUETOOTH, SOCK_RAW, BTPROTO_HCI);
    if (s < 0) {
        perror("socket(AF_BLUETOOTH)");
        return 1;
    }

    if (mode == 2) {
        struct hci_dev_info di;
        memset(&di, 0, sizeof(di));
        di.dev_id = (uint16_t)dev_id;
        if (ioctl(s, HCIGETDEVINFO, (unsigned long)&di) < 0) {
            perror("ioctl(HCIGETDEVINFO)");
            close(s);
            return 1;
        }
        close(s);
        int is_up = (di.flags & (1 << HCI_UP)) && (di.flags & (1 << HCI_RUNNING));
        printf("hci%d: %s (BD Address: %02X:%02X:%02X:%02X:%02X:%02X)\n",
               dev_id, is_up ? "UP RUNNING" : "DOWN",
               di.bdaddr.b[5], di.bdaddr.b[4], di.bdaddr.b[3],
               di.bdaddr.b[2], di.bdaddr.b[1], di.bdaddr.b[0]);
        return is_up ? 0 : 2;
    }

    if (mode == 0) {
        if (ioctl(s, HCIDEVDOWN, dev_id) < 0) {
            perror("ioctl(HCIDEVDOWN)");
            close(s);
            return 1;
        }
        printf("hci%d is DOWN\n", dev_id);
    } else {
        if (ioctl(s, HCIDEVUP, dev_id) < 0) {
            if (errno != EALREADY) {
                perror("ioctl(HCIDEVUP)");
                close(s);
                return 1;
            }
        }
        // Enable page scan + inquiry scan (piscan = 0x03)
        struct hci_dev_req dr;
        dr.dev_id = (uint16_t)dev_id;
        dr.dev_opt = SCAN_PAGE | SCAN_INQUIRY;
        ioctl(s, HCISETSCAN, (unsigned long)&dr);

        // Enable simple pairing mode (sspmode 1)
        dr.dev_opt = 1;
        ioctl(s, HCISETSMPAIR, (unsigned long)&dr);

        printf("hci%d is UP RUNNING PSCAN ISCAN\n", dev_id);
    }

    close(s);
    return 0;
}
