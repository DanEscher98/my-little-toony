-- Filetype detection for TOON files
vim.filetype.add({
  extension = {
    toon = 'toon',
  },
  pattern = {
    ['.*%.toon'] = 'toon',
  },
})
