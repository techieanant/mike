import { createClient } from "@supabase/supabase-js";

const supabaseUrl =
    process.env.NEXT_PUBLIC_SUPABASE_URL || "http://localhost:8000";
const supabaseAnonKey =
    process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_DEFAULT_KEY ||
    "placeholder-build-time-key";

export const supabase = createClient(supabaseUrl, supabaseAnonKey);
