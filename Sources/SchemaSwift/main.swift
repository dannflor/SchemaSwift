import ArgumentParser
import SwiftgreSQL
import SchemaSwiftLibrary
import Foundation

struct SchemaSwift: ParsableCommand {
    static var configuration = CommandConfiguration(
        abstract: "A utility for generating Swift row structs from a Postgres schema.",
        version: "1.0.0",
        subcommands: [Generate.self],
        defaultSubcommand: Generate.self
    )
}

struct Generate: ParsableCommand {
    @Option(help: "The full url for the Postgres server, with username, password, database name, and port.")
    var url: String

    @Option(
        name: [.customShort("o"), .long],
        help: "The location of the file containing the output. Will output to stdout if a file is not specified."
    )
    var output: String?

    @Option(
        help: "The schema in the database to generate models for. Will default to \"public\" if not specified."
    )
    var schema: String = "public"

    func run() throws {
        let database = try Database(url: url)

        let enums = try database.fetchEnumTypes(schema: schema)

        let tables = try database.fetchTableNames(schema: schema).map({ try database.fetchTableDefinition(tableName: $0) })

        var string = """
        /**
         * AUTO-GENERATED FILE - \(Date()) - DO NOT EDIT!
         *
         * This file was automatically generated by SwiftSchema
         *
         */

        import Foundation


        """

        for enumDefinition in enums {
            string += """
            enum \(Inflections.upperCamelCase(Inflections.singularize(enumDefinition.name))): String, Codable, CaseIterable {
                static let enumName = "\(enumDefinition.name)"


            """

            for value in enumDefinition.values {
                string += """
                    case \(Inflections.lowerCamelCase(value)) = "\(value)"

                """

            }

            string += """
            }


            """
        }

        for table in tables {
            string += """
            struct \(Inflections.upperCamelCase(Inflections.singularize(table.name))): Codable {
                static let tableName = "\(table.name)"


            """

            for column in table.columns {
                string += """
                    let \(Inflections.lowerCamelCase(column.name)): \(column.swiftType(including: enums))

                """
            }

            string += """

                enum CodingKeys: String, CodingKey {

            """

            for column in table.columns {
                string += """
                        case \(Inflections.lowerCamelCase(column.name)) = "\(column.name)"

                """
            }
            string += """
                }

            """


            string += """
            }


            """
        }

        if let outputPath = output {
            let url = URL(fileURLWithPath: outputPath)
            try string.write(to: url, atomically: true, encoding: .utf8)
        } else {
            print(string)
        }
    }
}

SchemaSwift.main()
