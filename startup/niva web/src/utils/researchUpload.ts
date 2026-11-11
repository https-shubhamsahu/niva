export interface UploadDatasetCsvParams {
  csvContent: string;
  sampleCount: number;
  metadata?: {
    sessionId?: string;
    trialId?: string;
    diseaseLabel?: string;
  };
}

export interface UploadDatasetCsvResult {
  statusCode: number;
  message: string;
  location?: string;
  responseBody?: unknown;
}

const resolveUploadEndpoint = (): string => {
  return ((import.meta as ImportMeta & { env?: Record<string, string | undefined> }).env?.VITE_DATASET_UPLOAD_URL || '').trim();
};

const resolveUploadToken = (): string => {
  return ((import.meta as ImportMeta & { env?: Record<string, string | undefined> }).env?.VITE_DATASET_UPLOAD_TOKEN || '').trim();
};

export const getDatasetUploadEndpoint = (): string => {
  return resolveUploadEndpoint();
};

export const uploadDatasetCsvToBackend = async (
  params: UploadDatasetCsvParams
): Promise<UploadDatasetCsvResult> => {
  const endpoint = resolveUploadEndpoint();

  if (!endpoint) {
    throw new Error('Dataset upload endpoint is not configured. Set VITE_DATASET_UPLOAD_URL in .env.local.');
  }

  const timestamp = new Date().toISOString();
  const filename = `gaitguard_esp32_dataset_${timestamp.replace(/[:.]/g, '-')}.csv`;
  const blob = new Blob([params.csvContent], { type: 'text/csv;charset=utf-8;' });

  const formData = new FormData();
  formData.append('file', blob, filename);
  formData.append('sampleCount', String(params.sampleCount));
  formData.append('generatedAt', timestamp);
  formData.append('datasetType', 'esp32-biomechanics');

  if (params.metadata?.sessionId) {
    formData.append('sessionId', params.metadata.sessionId);
  }
  if (params.metadata?.trialId) {
    formData.append('trialId', params.metadata.trialId);
  }
  if (params.metadata?.diseaseLabel) {
    formData.append('diseaseLabel', params.metadata.diseaseLabel);
  }

  const token = resolveUploadToken();
  const headers: HeadersInit = {};
  if (token) {
    headers.Authorization = `Bearer ${token}`;
  }

  const response = await fetch(endpoint, {
    method: 'POST',
    body: formData,
    headers,
  });

  let responseBody: unknown = null;
  const contentType = response.headers.get('content-type') || '';

  if (contentType.includes('application/json')) {
    responseBody = await response.json();
  } else {
    responseBody = await response.text();
  }

  if (!response.ok) {
    const fallbackMessage = typeof responseBody === 'string' && responseBody.trim()
      ? responseBody
      : `Upload failed with status ${response.status}.`;
    throw new Error(fallbackMessage);
  }

  const location =
    typeof responseBody === 'object' && responseBody !== null && 'location' in responseBody
      ? String((responseBody as { location?: unknown }).location || '')
      : undefined;

  return {
    statusCode: response.status,
    message: 'Dataset uploaded successfully.',
    location,
    responseBody,
  };
};
