import React, { useState, useRef } from 'react';
import {
  Box,
  TextField,
  IconButton,
  Paper,
  List,
  ListItem,
  ListItemText,
  Typography,
  useTheme,
} from '@mui/material';
import SearchIcon from '@mui/icons-material/Search';
import ClearIcon from '@mui/icons-material/Clear';

export interface SearchBarProps {
  query: string;
  onSearch: (query: string) => void;
  placeholder?: string;
  searchHistory?: string[];
  onHistoryItemClick?: (item: string) => void;
  onClearHistory?: () => void;
}

export const SearchBar: React.FC<SearchBarProps> = ({
  query,
  onSearch,
  placeholder = 'Search...',
  searchHistory = [],
  onHistoryItemClick,
  onClearHistory,
}) => {
  const [showHistory, setShowHistory] = useState(false);
  const inputRef = useRef<HTMLInputElement>(null);
  const theme = useTheme();

  const handleKeyPress = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter') {
      setShowHistory(false);
    }
  };

  const handleHistoryItemClick = (item: string) => {
    onHistoryItemClick?.(item);
    setShowHistory(false);
    inputRef.current?.focus();
  };

  return (
    <Box position="relative">
      <TextField
        fullWidth
        variant="outlined"
        value={query}
        onChange={(e) => onSearch(e.target.value)}
        onKeyPress={handleKeyPress}
        onFocus={() => setShowHistory(true)}
        placeholder={placeholder}
        inputRef={inputRef}
        InputProps={{
          startAdornment: (
            <IconButton edge="start" disabled>
              <SearchIcon />
            </IconButton>
          ),
          endAdornment: query && (
            <IconButton edge="end" onClick={() => onSearch('')}>
              <ClearIcon />
            </IconButton>
          ),
        }}
        sx={{
          '& .MuiOutlinedInput-root': {
            backgroundColor: theme.palette.background.paper,
            '&:hover .MuiOutlinedInput-notchedOutline': {
              borderColor: theme.palette.primary.main,
            },
            '&.Mui-focused .MuiOutlinedInput-notchedOutline': {
              borderColor: theme.palette.primary.main,
            },
          },
        }}
      />

      {showHistory && searchHistory.length > 0 && (
        <Paper
          elevation={3}
          sx={{
            position: 'absolute',
            top: '100%',
            left: 0,
            right: 0,
            mt: 1,
            maxHeight: 300,
            overflow: 'auto',
            backgroundColor: theme.palette.background.paper,
          }}
        >
          <List>
            {searchHistory.map((item) => (
              <ListItem
                key={item}
                button
                onClick={() => handleHistoryItemClick(item)}
                sx={{
                  '&:hover': {
                    backgroundColor: theme.palette.action.hover,
                  },
                }}
              >
                <ListItemText primary={item} />
              </ListItem>
            ))}
            {onClearHistory && (
              <ListItem
                button
                onClick={onClearHistory}
                sx={{
                  '&:hover': {
                    backgroundColor: theme.palette.error.main,
                    '& .MuiTypography-root': {
                      color: theme.palette.error.contrastText,
                    },
                  },
                }}
              >
                <Typography color="error">Clear History</Typography>
              </ListItem>
            )}
          </List>
        </Paper>
      )}
    </Box>
  );
};

export default SearchBar; 