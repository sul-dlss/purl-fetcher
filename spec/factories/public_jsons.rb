FactoryBot.define do
  factory :public_json do
    data do
      Cocina::RSpec::Factories.build(:dro_with_metadata)
                              .new(access: { view: 'world' },
                                   structural: {
                                     contains: [
                                       {
                                         type: Cocina::Models::FileSetType.image,
                                         externalIdentifier: 'https://cocina.sul.stanford.edu/fileSet/cg767mn6478-2064a12c-c97f-4c66-85eb-1693fd5ae56f',
                                         label: 'Object 1',
                                         version: 1,
                                         structural: {
                                           contains: [
                                             {
                                               type: Cocina::Models::ObjectType.file,
                                               externalIdentifier: 'https://cocina.sul.stanford.edu/file/cg767mn6478-2064a12c-c97f-4c66-85eb-1693fd5ae56f/2542A.tiff',
                                               label: '2542A.tiff',
                                               filename: '2542A.tiff',
                                               hasMimeType: 'image/tiff',
                                               size: 3_182_927,
                                               version: 1,
                                               access: {
                                                 view: 'world',
                                                 download: 'none'
                                               },
                                               administrative: {
                                                 publish: false,
                                                 sdrPreserve: true,
                                                 shelve: false
                                               },
                                               hasMessageDigests: [
                                                 {
                                                   type: "sha1",
                                                   digest: "1f09f8796bfa67db97557f3de48a96c87b286d32"
                                                 },
                                                 {
                                                   type: "md5",
                                                   digest: "5b79c8570b7ef582735f912aa24ce5f2"
                                                 }
                                               ]
                                             },
                                             {
                                               type: Cocina::Models::ObjectType.file,
                                               externalIdentifier: 'https://cocina.sul.stanford.edu/file/cg767mn6478-2064a12c-c97f-4c66-85eb-1693fd5ae56f/2542A.jp2',
                                               label: '2542A.jp2',
                                               filename: '2542A.jp2',
                                               hasMimeType: 'image/jp2',
                                               size: 11_043,
                                               version: 1,
                                               access: {
                                                 view: 'world',
                                                 download: 'none'
                                               },
                                               administrative: {
                                                 publish: true,
                                                 sdrPreserve: false,
                                                 shelve: true
                                               },
                                               hasMessageDigests: [
                                                 {
                                                   type: "sha1",
                                                   digest: "39feed6ee1b734cab2d6a446e909a9fc7ac6fd01"
                                                 },
                                                 {
                                                   type: "md5",
                                                   digest: "cd5ca5c4666cfd5ce0e9dc8c83461d7a"
                                                 }
                                               ]
                                             }
                                           ]
                                         }
                                       }
                                     ]
                                   }).to_json
    end
  end
end
