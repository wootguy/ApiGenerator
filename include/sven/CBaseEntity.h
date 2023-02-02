// This code was automatically generated by the ApiGenerator plugin.
// Prefer updating the generator code instead of editing this directly.
// "u[]" variables are unknown data.

// Example entity: player
class CBaseEntity {
public:
    byte u0[4];
    entvars_t* pev; // Entity variables
    byte u1[48];
    bool m_fOverrideClass; // Whether this entity overrides the classification.
    byte u2[3];
    int m_iClassSelection; // The overridden classification.
    byte u3[20];
    float m_flMaximumFadeWait; // Maximum fade wait time.
    float m_flMaximumFadeWaitB; // Maximum fade wait time B.
    bool m_fCanFadeStart; // Whether fading can start.
    byte u4[11];
    bool m_fCustomModel; // Whether a custom model is used.
    byte u5[3];
    vec3_t m_vecLastOrigin; // Last origin vector
    string_t targetnameOutFilterType; // Target name out filter type.
    string_t classnameOutFilterType; // Class name out filter type.
    string_t targetnameInFilterType; // Target name in filter type.
    string_t classnameInFilterType; // Class name in filter type.
    byte u6[16];
    int m_iOriginalRenderMode; // Original render model.
    int m_iOriginalRenderFX; // Original render FX.
    float m_flOriginalRenderAmount; // Original render amount.
    vec3_t m_vecOriginalRenderColor; // Original render color.
};