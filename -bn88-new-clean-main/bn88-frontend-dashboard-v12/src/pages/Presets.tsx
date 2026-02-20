// src/pages/Presets.tsx
import { useEffect, useState } from "react";
import { API } from "../lib/api";

export default function Presets({ tenant: _tenant }: { tenant: string }) {
  void _tenant;
  const [items, setItems] = useState<any[]>([]);
  const [name, setName] = useState("");
  const [systemPrompt, setSystemPrompt] = useState("");

  const load = async () => {
    const res = await API.get(`/admin/ai/presets`);
    setItems(res.data.items || []);
  };

  useEffect(() => { load(); }, []);

  const create = async () => {
    await API.post(`/admin/ai/presets`, { name, systemPrompt });
    setName(""); setSystemPrompt("");
    load();
  };

  return (
    <div className="p-4">
      <h2 className="font-semibold mb-3">AI Presets</h2>
      <div className="flex gap-2 mb-3">
        <input className="border p-2 flex-1" placeholder="Preset name" value={name}
          onChange={(e) => setName(e.target.value)} />
        <input className="border p-2 flex-1" placeholder="System prompt" value={systemPrompt}
          onChange={(e) => setSystemPrompt(e.target.value)} />
        <button onClick={create} className="bg-blue-500 text-white px-3 py-2">Add</button>
      </div>
      <ul>
        {items.map((p) => (
          <li key={p.id} className="border-b py-2">
            <strong>{p.name}</strong> — {p.systemPrompt}
          </li>
        ))}
      </ul>
    </div>
  );
}