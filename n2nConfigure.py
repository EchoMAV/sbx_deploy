#!/usr/bin/env python3
'''
Configure N2N
'''
import logging, os, subprocess, sys

__version__ = '0.3.7'

logger = logging.getLogger(__name__)

# /usr/local/echopilot/edge.conf
# Fill in template as needed and write configuration file
_EDGE_CONF_PATH = os.path.join(os.path.sep,'usr','local','echopilot','edge.conf')
_EDGE_CONF = {
    'd':'edge0',
    'c':'',
    'k':'',
    'a':'',
    'n':'',
    'l':'data.echomav.com:1200', # supernode (video.mavnet.online port 1200)
    'r':None,
}
_DEFAULT_SUPERNODE_PORT = 1200

def _syscall(cmd: str, ignore: bool = False):
    """Call OS with a diagnostic log."""
    logger.info(cmd)
    try:
        subprocess.check_call(cmd.split(' '), shell=False)
    except subprocess.CalledProcessError as e:
        logger.error(str(e))
        if not ignore:
            raise

# https://stackoverflow.com/questions/33750233/convert-cidr-to-subnet-mask-in-python
def _cidr_to_netmask(cidr):
    """Convert CIDR notation to IP, dotted-decimal netmask"""
    import socket, struct

    network, bits = cidr.split('/')
    m = 32 - int(bits)
    netmask = socket.inet_ntoa(struct.pack('!I', (1 << 32) - (1 << m)))
    return network, netmask

def edge_active():
    """Determine if the VPN is up and running."""
    return os.system('systemctl status edge') == 0

def edge(start: bool = False, cid: str = None, psk: str = None, ip: str = None, dev: str = 'edge0', **kwargs):
    """
    Become a WiFi access point with the credentials as given

    :option start:  A boolean indicating whether to start or stop the VPN
    :option cid:    A string containing the community id to connect to
    :option psk:    A string containing the pre-shared key to use
    :option ip:     A string representing the IP address to assign to the edge node
    :option dev:    A string representing the TAP network device (NONE will inhibit routing)

    If the provided CID/PSK/IP are None (the default), then the edge node is stopped or started without changing
    the previous configuration.  In this way, one can 'provision' using a full set
    of parameters, then enable/disable using only the 'CID' parameter.

    IP can be given as dotted-decimal (xxx.xxx.xxx.xxx) or CIDR (xxx.xxx.xxx.xxx/nnn),
    the latter also assigning the appropriate netmask.

    Keyword arguments:

    :option aes:        A boolean indicating whether to use AES (True) or TwoFish (False, default)
    :option enable:     A boolean indicating whether to enable or disable the VPN at boot
    :option multicast:  A boolean indicating whether to enable Multicast (True, default) or not

    """
    if not start:
        _syscall('systemctl stop edge')

    if cid is None or psk is None or ip is None:
        if start:
            _syscall('systemctl start edge')
        return

    conf = _EDGE_CONF.copy()

    conf['c'] = cid
    conf['k'] = psk
    conf['a'] = ip
    routing = kwargs.get('routing', None)
    conf['n'] = routing
    #if conf['a'].rfind('/') >= 0:
    #    ip,mask = _cidr_to_netmask(conf['a'])
    #    conf['a'] = ip
    #    conf['s'] = mask    # cause emission of -s=xxx.xxx.xxx.xxx
    if dev is not None:
        conf['d'] = dev
        conf['r'] = ''      # cause emission of '-r'
    else:
        conf['r'] = None    # inhibit emission of '-r'
    supernode = kwargs.get('supernode', None)
    if supernode is not None:
        conf['l'] = supernode
        if conf['l'].rfind(':') < 0:
            conf['l'] = '{}:{}'.format(supernode,_DEFAULT_SUPERNODE_PORT)
    aes = kwargs.get('aes', False)
    if aes:
        conf['A'] = ''      # cause emission of '-A'
    multicast = kwargs.get('multicast', True)
    if multicast:
        conf['E'] = ''      # cause emission of '-E'

    # https://bugs.python.org/issue29214
    # NB: if the file already exists, it doesn't change the permissions
    os.umask(0o027)
    with open(_EDGE_CONF_PATH, 'w') as f:
        for k in conf:
            if conf[k] is not None:
                if len(conf[k])>0:
                    f.write('-'+k+'='+conf[k]+'\n')
                else:
                    f.write('-'+k+'\n')

    enable = kwargs.get('enable', False)
    _syscall('systemctl {} edge'.format('enable' if enable else 'disable'))

    if start:
        _syscall('systemctl restart edge')


# ---------------------------------------------------------------------------
# For command-line testing
# ---------------------------------------------------------------------------

def _auth(cid):
    """Get a pre-shared key as input from the user."""
    import getpass
    psk = getpass.getpass('Enter Passphrase for N2N\n{}: '.format(cid),None)
    return psk

def _input(prompt, default=None):
    """Interactive entry w/prompt and default value"""
    if default is None:
        sys.stderr.write(prompt+': ')
    else:
        sys.stderr.write(prompt+' ({}): '.format(default))
    u = input('')
    return u if len(u)>0 else default

if __name__ == "__main__":
    from argparse import ArgumentParser, SUPPRESS
    import json

    parser = ArgumentParser(description=__doc__)
    parser.add_argument('-A', '--aes', action='store_true', default=False, help='Use AES (default: %(default)s)')
    parser.add_argument('-a', '--address', metavar='IP', type=str, default=None, help='IP address of edge node (default: %(default)s)')
    parser.add_argument('-c', '--community', metavar='N', type=str, default=None, help='Community name (default: %(default)s)')
    parser.add_argument(      '--debug', action='store_true', help=SUPPRESS, default=False)
    parser.add_argument('-d', '--device', metavar='DEV', type=str, default=None, help='TUN device (default: %(default)s)')
    parser.add_argument(      '--enable', action='store_true', default=False, help='Enable EDGE service at boot (default: %(default)s)')
    parser.add_argument(      '--interactive', action='store_true', default=False, help='Interactive provisioning/verification (default: %(default)s)')
    parser.add_argument(      '--mavnet', metavar='PATH', default=None, help='Use MAVNet configuration file to provision (default: %(default)s)')
    parser.add_argument('-E', '--multicast', action='store_true', default=False, help='Accept Multicast (default: %(default)s)')
    parser.add_argument('-k', '--key', metavar='N', type=str, default=None, help='Encryption Key (default: %(default)s)')
    parser.add_argument('-l', '--supernode', metavar='IP:PORT', type=str, default='52.222.1.20:1200', help='Supernode address:port (default: %(default)s)')
    parser.add_argument(      '--start', action='store_true', default=False, help='Start EDGE service (default: %(default)s)')
    parser.add_argument(      '--version', action='version', version='%(prog)s '+__version__)
    args = parser.parse_args()

    # make logging work for more than just WARNINGS+
    fmt = '%(asctime)s:%(levelname)s:%(name)s:%(funcName)s:%(message)s'
    lvl = logging.DEBUG if args.debug else logging.INFO
    logging.basicConfig(format=fmt,level=lvl)

    # establish configuration (via MAVNet config, interactive or command line)
    d = {}
    if args.mavnet is not None:
        cfg = json.load(open(args.mavnet,'r'))
        d['aes'] = False        # FIXME: needs to be True after testing
        d['dev'] = 'edge0'
        d['enable'] = cfg['los']['active'] or args.enable
        d['multicast'] = True
        d['psk'] = cfg['los']['radio']['password']
        d['supernode'] = '52.222.1.20:1200' # TODO: to be added into provisioning file
        d['start'] = args.start
        d['routing'] = '225.0.0.0/8:0.0.0.0'
        # TODO: vpn convention is to use 172.22.x.y with x.y coming from LOS[RADIO][DHCP][START]
        los = cfg['los']['radio']['dhcp']['lan']['start'].split('.')
        d['ip'] = '172.22.{}.{}'.format(los[2],los[3])
        config = os.path.sep.join(args.mavnet.split(os.path.sep)[0:-1])+os.path.sep+'config'
        try:
            # extract comm group
            with open(config,'r') as f:
                c = f.readline().strip().split(',')
                d['cid'] = c[0].replace('\0','').strip()
        except FileNotFoundError as e:
            logging.error(str(e)+'\n')
            if args.interactive:
                d['cid'] = _input('Select MAVNet comm group')
            else:
                raise

        if args.interactive:
            verify = '\nVerify Configuration:\n{}\nOK?'.format(json.dumps(d,indent=2))
            ok = True if _input(verify, default='Yes').lower() in ['y','yes','t','true'] else False
            if not ok:
                sys.exit(1)

    elif args.interactive:
        d['cid'] = _input('Choose N2N Community', default='echomavnetwork')
        d['ip'] = _input('Choose N2N IPv4/netmask (e.g. 172.21.x.y/16)', default='172.21.1.4/16')
        d['psk'] = _auth(d['cid'])
        d['supernode'] = _input('Choose Supernode', default='data.echomav.com:1200')
        d['aes'] = True if _input('Use AES?', default='No').lower() in ['y','yes','t','true'] else False
        d['multicast'] = True if _input('Enable Multicast?', default='Yes').lower() in ['y','yes','t','true'] else False
        d['dev'] = _input('Choose TUN device and enable routing?', default='edge0')
        d['enable'] = True if _input('Enable EDGE as service?', default='Yes').lower() in ['y','yes','t','true'] else False
        d['start'] = True if _input('Start EDGE now?', default='Yes').lower() in ['y','yes','t','true'] else False
        d['routing'] = '225.0.0.0/8:0.0.0.0'

        verify = '\nVerify Configuration:\n{}\nOK?'.format(json.dumps(d,indent=2))
        ok = True if _input(verify, default='Yes').lower() in ['y','yes','t','true'] else False
        if not ok:
            sys.exit(1)

    else:
        d['aes'] = args.aes
        d['ip'] = args.address
        d['cid'] = args.community
        d['dev'] = args.device
        d['enable'] = args.enable
        d['multicast'] = args.multicast
        d['psk'] = args.key
        d['supernode'] = args.supernode
        d['start'] = args.start
        d['routing'] = '225.0.0.0/8:0.0.0.0'

        if d['psk'] is None:
            d['psk'] = _auth(d['cid'])

    logger.debug(str(d))
    edge(**d)

