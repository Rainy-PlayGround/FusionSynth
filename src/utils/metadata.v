module utils

import toml

const embedded_file = $embed_file('./assets/project.toml')

pub struct IMetadata {
pub:
  name string
  version string
  license string
  internal_version bool
  authors string
  codename string
}

pub fn metadata_reader() IMetadata {
  toml_content := embedded_file.to_string()

  mdr := toml.parse_text(toml_content) or {
    panic('Failed to parse embedded TOML: ${err}')
  }

  pj_name := mdr.value('projects.name').string()
  pj_version := mdr.value('projects.version').string()
  pj_license := mdr.value('projects.license').string()
  pj_codename := mdr.value('projects.codename').string()
  pj_internal_version := mdr.value('projects.internal_version').bool()
  pj_authors_raw := mdr.value('projects.authors')
  mut pj_authors := ''

  if pj_authors_raw is []toml.Any {
    mut authors := []string{}
    for item in pj_authors_raw {
      authors << item.string()
    }
    pj_authors = authors.join(', ')
  } else if pj_authors_raw is string {
    pj_authors = pj_authors_raw
  }

  return IMetadata{
    name: pj_name,
    version: pj_version,
    license: pj_license,
    internal_version: pj_internal_version,
    authors: pj_authors,
    codename: pj_codename
  }
}