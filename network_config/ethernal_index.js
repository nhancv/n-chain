const axios = require('axios');

const API_TOKEN = process.argv[2]; // DO NOT CHANGE
const WORKSPACE_NAME = 'Explorer'; // DO NOT CHANGE
const API_ROOT = 'http://localhost:8888'; // DO NOT CHANGE

const EXPLORER_DOMAIN = 'nhancv.com'; // CHANGE: <--- All explorers will be created under this domain
const EXPLORER_SLUG = 'scan'; // CHANGE: <--- This will be used for the subdomain. Change to your subdomain
const RPC_SERVER = 'https://rpc.nhancv.com'; // CHANGE: <--- YOUR RPC SERVER
const NETWORK_ID = 1584821; // CHANGE: <--- YOUR NETWORK CHAIN_ID
const NETWORK_TOKEN = 'ETH'; // CHANGE: <--- YOUR NETWORK CHAIN_SYMBOL
const SECRET = 'xxx'; // CHANGE: <--- Secret that you defined in your .env.prod file

const THEME = {"default":{}};
const HEADERS = {
  headers: {
    'Authorization': `Bearer ${API_TOKEN}`,
    'Content-Type': 'application/json'
  }
}

async function main() {
  try {
    const workspacePayload = {
      name: WORKSPACE_NAME,
      workspaceData: {
        chain: 'other',
        networkId: NETWORK_ID,
        rpcServer: RPC_SERVER,
        public: true,
        tracing: 'disabled'
      }
    }

    const workspace = (await axios.post(`${API_ROOT}/api/workspaces`, { data: workspacePayload }, HEADERS)).data;

    const explorerPayload = {
      workspaceId: workspace.id,
      name: WORKSPACE_NAME,
      rpcServer: RPC_SERVER,
      theme: THEME,
      token: NETWORK_TOKEN,
      domain: `${EXPLORER_SLUG}.${EXPLORER_DOMAIN}`,
      slug: EXPLORER_SLUG,
      chainId: NETWORK_ID
    }

    const explorer = (await axios.post(`${API_ROOT}/api/explorers?secret=${SECRET}`, { data: explorerPayload }, HEADERS)).data;
    console.log(`https://${explorer.domain}`);
  } catch(error) {
    console.log(error)
    console.log(`Error: ${error.response.data}`);
  }
}

main();
