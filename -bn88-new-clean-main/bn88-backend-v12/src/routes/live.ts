// src/routes/live.ts
import { Router } from "express";
import { sseHandler } from "../live";

export const live = Router();

live.get("/live/:tenant", sseHandler);
