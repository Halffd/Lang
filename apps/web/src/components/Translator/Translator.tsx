import React, { useState } from 'react';
import {
  Box,
  TextField,
  Select,
  MenuItem,
  Button,
  Typography,
  useTheme,
  FormControl,
  InputLabel,
  Stack,
  ToggleButtonGroup,
  ToggleButton,
  Paper,
} from '@mui/material';
import { TranslationService } from '../../services/TranslationService';
import { languageOptions } from './languageOptions';

export type TranslationMode = 'per-word' | 'dictionary' | 'scraping';

export interface TranslatorProps {
  onTranslate: (text: string, sourceLang: string, targetLang: string, mode: TranslationMode) => Promise<string>;
}

export const Translator: React.FC<TranslatorProps> = ({ onTranslate }) => {
  const [sourceText, setSourceText] = useState('');
  const [targetText, setTargetText] = useState('');
  const [sourceLanguage, setSourceLanguage] = useState('en');
  const [targetLanguage, setTargetLanguage] = useState('ja');
  const [isTranslating, setIsTranslating] = useState(false);
  const [mode, setMode] = useState<TranslationMode>('per-word');
  const theme = useTheme();

  const handleTranslate = async () => {
    if (!sourceText.trim()) return;
    
    setIsTranslating(true);
    try {
      const result = await onTranslate(sourceText, sourceLanguage, targetLanguage, mode);
      setTargetText(result);
    } catch (error) {
      console.error('Translation error:', error);
      setTargetText('Translation failed. Please try again.');
    } finally {
      setIsTranslating(false);
    }
  };

  const handleModeChange = (_: React.MouseEvent<HTMLElement>, newMode: TranslationMode) => {
    if (newMode !== null) {
      setMode(newMode);
    }
  };

  return (
    <Stack spacing={3}>
      <Paper elevation={1} sx={{ p: 2 }}>
        <Typography variant="subtitle1" gutterBottom>
          Translation Mode
        </Typography>
        <ToggleButtonGroup
          value={mode}
          exclusive
          onChange={handleModeChange}
          aria-label="translation mode"
          fullWidth
        >
          <ToggleButton value="per-word" aria-label="per word translation">
            Per Word
          </ToggleButton>
          <ToggleButton value="dictionary" aria-label="dictionary mode">
            Dictionary
          </ToggleButton>
          <ToggleButton value="scraping" aria-label="scraping mode">
            Scraping
          </ToggleButton>
        </ToggleButtonGroup>
      </Paper>

      <Box>
        <FormControl fullWidth>
          <InputLabel>Source Language</InputLabel>
          <Select
            value={sourceLanguage}
            onChange={(e) => setSourceLanguage(e.target.value)}
            label="Source Language"
          >
            {languageOptions.map((option) => (
              <MenuItem key={option.value} value={option.value}>
                {option.label}
              </MenuItem>
            ))}
          </Select>
        </FormControl>
      </Box>

      <TextField
        fullWidth
        multiline
        rows={4}
        value={sourceText}
        onChange={(e) => setSourceText(e.target.value)}
        placeholder={
          mode === 'per-word' 
            ? "Enter text to translate word by word..." 
            : mode === 'dictionary'
            ? "Enter text to look up in dictionary..."
            : "Enter URL or text to scrape and translate..."
        }
        variant="outlined"
        sx={{
          '& .MuiOutlinedInput-root': {
            backgroundColor: theme.palette.background.paper,
          },
        }}
      />

      <Button
        variant="contained"
        onClick={handleTranslate}
        disabled={isTranslating || !sourceText.trim()}
        sx={{
          backgroundColor: theme.palette.primary.main,
          '&:hover': {
            backgroundColor: theme.palette.primary.dark,
          },
        }}
      >
        {isTranslating ? 'Translating...' : 'Translate'}
      </Button>

      <Box>
        <FormControl fullWidth>
          <InputLabel>Target Language</InputLabel>
          <Select
            value={targetLanguage}
            onChange={(e) => setTargetLanguage(e.target.value)}
            label="Target Language"
          >
            {languageOptions.map((option) => (
              <MenuItem key={option.value} value={option.value}>
                {option.label}
              </MenuItem>
            ))}
          </Select>
        </FormControl>
      </Box>

      <TextField
        fullWidth
        multiline
        rows={4}
        value={targetText}
        placeholder="Translation will appear here..."
        variant="outlined"
        InputProps={{
          readOnly: true,
        }}
        sx={{
          '& .MuiOutlinedInput-root': {
            backgroundColor: theme.palette.background.paper,
          },
        }}
      />
    </Stack>
  );
};

export default Translator; 