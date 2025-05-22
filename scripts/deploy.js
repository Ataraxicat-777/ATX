import { useState } from "react";
import { ethers } from "ethers";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";

const proxyAddress = "0xf2032dee384D8ECf4A2F4244d6C7e73f73eB2289";
const abi = [
  "function mint(address to, uint256 amount) public"
];

export default function ClaimATXIA() {
  const [status, setStatus] = useState("");

  const handleClaim = async () => {
    try {
      if (!window.ethereum) throw new Error("MetaMask not found");

      const provider = new ethers.BrowserProvider(window.ethereum);
      const signer = await provider.getSigner();
      const contract = new ethers.Contract(proxyAddress, abi, signer);
      const address = await signer.getAddress();
      const tx = await contract.mint(address, ethers.parseUnits("1000", 18));
      setStatus("Minting...");
      await tx.wait();
      setStatus("Successfully claimed 1000 $ATXIA!");
    } catch (err) {
      console.error(err);
      setStatus("Error: " + err.message);
    }
  };

  return (
    <div className="grid place-items-center h-screen">
      <Card className="w-full max-w-md text-center">
        <CardContent className="p-6">
          <h1 className="text-xl font-bold mb-4">Claim Your $ATXIA</h1>
          <p className="mb-4">Connect your wallet and claim 1,000 testnet tokens.</p>
          <Button onClick={handleClaim}>Claim $ATXIA</Button>
          <p className="mt-4 text-sm text-gray-500">{status}</p>
        </CardContent>
      </Card>
    </div>
  );
}
