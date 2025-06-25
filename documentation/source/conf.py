# Configuration file for the Sphinx documentation builder.
# docs/source/conf.py

# -- Project information -----------------------------------------------------
project = 'Diploma Game Project'
copyright = '2024, Олександр Алещенко'
author = 'Олександр Алещенко'
release = '1.0.0'

# -- General configuration ---------------------------------------------------
extensions = [
    'sphinx.ext.autodoc',
    'sphinx.ext.viewcode',
    'sphinx.ext.napoleon',
]

templates_path = ['_templates']
exclude_patterns = ['_build', 'Thumbs.db', '.DS_Store']

# -- Options for HTML output -------------------------------------------------
html_theme = 'sphinx_rtd_theme'

html_theme_options = {
    'collapse_navigation': False,
    'sticky_navigation': True,
    'navigation_depth': 4,
    'includehidden': True,
    'titles_only': False
}

html_static_path = ['_static']

# -- Language settings -------------------------------------------------------
language = 'uk'

# -- Custom CSS --------------------------------------------------------------
html_css_files = [
    'custom.css',
]