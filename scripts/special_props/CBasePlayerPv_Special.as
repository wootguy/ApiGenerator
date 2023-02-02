array<PvProp> CBasePlayerPv_Special = {
	PvProp("m_rgAmmo[64]", FIELD_INT, "Player ammo amount", // to find array size, increase the value until there's an error
		function(ent) { return cast<CBasePlayer@>(ent).m_rgAmmo(g_arr_idx); },
		function(ent, value) { cast<CBasePlayer@>(ent).m_rgAmmo(g_arr_idx, value.v32); }
	)
};
