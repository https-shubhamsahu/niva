export type GaitMode = 'Normal' | 'Parkinson' | 'Stroke' | 'Neuropathy' | 'Foot Drop' | 'Ataxia';

export interface GaitFrame {
  heel: number;
  mt1: number;
  mt5: number;
  toe: number;
  impact: number;
  stanceRatio: number;
  imuRollVariance: number;
  explanation: string;
}

export const getDiseaseExplanation = (mode: GaitMode): string => {
  switch (mode) {
    case 'Parkinson': return "Low heel impact combined with increased stance duration suggests Parkinsonian shuffling gait.";
    case 'Stroke': return "Medial-lateral pressure asymmetry detected indicating hemiplegic gait imbalance.";
    case 'Neuropathy': return "Sustained forefoot pressure may increase risk of diabetic plantar ulceration.";
    case 'Foot Drop': return "Absent heel strike and forefoot slap characteristic of dorsiflexion weakness.";
    case 'Ataxia': return "Unstable gait and high IMU roll variance indicative of cerebellar ataxia.";
    case 'Normal':
    default: return "Balanced pressure progression and stable temporal parameters detected.";
  }
}

export const generateGaitFrame = (mode: GaitMode, timeMs: number): GaitFrame => {
  // Use time to simulate walking cycle (sine wave for heel to toe progression)
  const cycleTime = mode === 'Parkinson' ? 1200 : mode === 'Ataxia' ? 1300 : mode === 'Foot Drop' ? 1100 : 1000;
  const phase = (timeMs % cycleTime) / cycleTime; // 0 to 1
  
  // Base values for each mode based on problem description
  let baseHeel = 80;
  let baseMt1 = 60;
  let baseMt5 = 55;
  let baseToe = 70;
  let impact = 80;
  let stanceRatio = 0.60;
  let imuRollVariance = 0.5;
  
  if (mode === 'Parkinson') {
    baseHeel = 30; baseMt1 = 50; baseMt5 = 48; baseToe = 40;
    impact = 20; stanceRatio = 0.75; imuRollVariance = 0.3;
  } else if (mode === 'Stroke') {
    baseHeel = 60; baseMt1 = 90; baseMt5 = 20; baseToe = 75;
    impact = 60; stanceRatio = 0.65; imuRollVariance = 1.2;
  } else if (mode === 'Neuropathy') {
    baseHeel = 35; baseMt1 = 95; baseMt5 = 85; baseToe = 50;
    impact = 50; stanceRatio = 0.60; imuRollVariance = 0.6;
  } else if (mode === 'Foot Drop') {
    baseHeel = 5; baseMt1 = 70; baseMt5 = 60; baseToe = 80;
    impact = 90; stanceRatio = 0.55; imuRollVariance = 0.8;
  } else if (mode === 'Ataxia') {
    baseHeel = 40 + Math.random() * 40;
    baseMt1 = 30 + Math.random() * 60;
    baseMt5 = 20 + Math.random() * 50;
    baseToe = 30 + Math.random() * 50;
    impact = 40 + Math.random() * 50;
    stanceRatio = 0.50 + Math.random() * 0.30;
    imuRollVariance = 2.0 + Math.random() * 3.0;
  }

  // Animation scaling for dynamic walking cycle
  // Heel strike peaks at phase 0.2
  // Toe off peaks at phase 0.7
  const heelScale = mode === 'Foot Drop' ? 0.2 : Math.max(0, Math.sin(phase * Math.PI));
  const toeScale = Math.max(0, Math.sin((phase - 0.5) * Math.PI));
  
  // Add some per-frame noise to make it look alive
  const applyNoise = (val: number, amp: number = 3) => val + (Math.random() - 0.5) * amp;

  // Blend base with walking phase
  const heel = applyNoise(baseHeel * (0.3 + 0.7 * heelScale));
  
  // Foot drop slaps the forefoot down immediately
  const mtScale = mode === 'Foot Drop' ? heelScale : toeScale;
  const mt1 = applyNoise(baseMt1 * (0.3 + 0.7 * mtScale));
  const mt5 = applyNoise(baseMt5 * (0.3 + 0.7 * mtScale));
  const toe = applyNoise(baseToe * (0.3 + 0.7 * toeScale));

  return {
    heel: Math.min(100, Math.max(0, heel)),
    mt1: Math.min(100, Math.max(0, mt1)),
    mt5: Math.min(100, Math.max(0, mt5)),
    toe: Math.min(100, Math.max(0, toe)),
    impact: applyNoise(impact, 5),
    stanceRatio: applyNoise(stanceRatio, 0.02),
    imuRollVariance: applyNoise(imuRollVariance, 0.1),
    explanation: getDiseaseExplanation(mode)
  };
};
