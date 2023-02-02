array<PvProp> CBasePlayerPv_Special = {
	// This property is special because it's only accessible via class methods.
	// It's also an array, and you need to find the size manually by increasing it here until there's an error
	PvProp("m_rgAmmo[64]", FIELD_INT, "Player ammo amount",
		function(ent) { return cast<CBasePlayer@>(ent).m_rgAmmo(g_arr_idx); },
		function(ent, value) { cast<CBasePlayer@>(ent).m_rgAmmo(g_arr_idx, value.v32); }
	)
};
