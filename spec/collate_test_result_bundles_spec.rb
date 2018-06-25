require 'plist'
require 'pry-byebug'

info_plist_1 = Plist.parse_xml('./spec/fixtures/AtomicBoy.test_result/Info.plist')
info_plist_2 = Plist.parse_xml('./spec/fixtures/AtomicBoy_0.test_result/Info.plist')
test_summaries_plist_1 = Plist.parse_xml('./spec/fixtures/AtomicBoy.test_result/TestSummaries.plist')
test_summaries_plist_2 = Plist.parse_xml('./spec/fixtures/AtomicBoy_0.test_result/TestSummaries.plist')

describe Fastlane::Actions::CollateTestResultBundlesAction do
  describe 'it handles invalid data' do
    it 'a failure occurs when non-existent test_result bundle is specified' do
      fastfile = "lane :test do
        collate_test_result_bundles(
          bundles: ['path/to/non_existent.test_result'],
          collated_bundle: 'path/to/report.test_result'
        )
      end"
      expect { Fastlane::FastFile.new.parse(fastfile).runner.execute(:test) }.to(
        raise_error(FastlaneCore::Interface::FastlaneError) do |error|
          expect(error.message).to match("Error: test_result bundle not found: 'path/to/non_existent.test_result'")
        end
      )
    end
  end

  describe 'it handles valid data' do
    it 'simply copies a :bundles value containing one test_result bundle' do
      fastfile = "lane :test do
        collate_test_result_bundles(
          bundles: ['path/to/fake.test_bundle'],
          collated_bundle: 'path/to/report.test_bundle'
        )
      end"
      allow(Dir).to receive(:exist?).with('path/to/fake.test_bundle').and_return(true)
      expect(FileUtils).to receive(:cp).with('path/to/fake.test_bundle', 'path/to/report.test_bundle')
      Fastlane::FastFile.new.parse(fastfile).runner.execute(:test)
    end

    it 'merges Info.plist files' do
      fastfile = "lane :test do
        collate_test_result_bundles(
          bundles: ['path/to/fake1.test_bundle', 'path/to/fake2.test_bundle'],
          collated_bundle: 'path/to/report.test_bundle'
        )
      end"
      test_result_bundle_files = {
        '1' => ['Info.plist'],
        '2' => ['Info.plist']
      }
      allow(Dir).to receive(:foreach).with(%r{path/to/fake\d\.test_bundle}) do |dirname, &_block|
        %r{path/to/fake(?<bundle_number>\d)\.test_bundle} =~ dirname

        _block.call(test_result_bundle_files[bundle_number].shift)
      end
      allow(Dir).to receive(:exist?).with('path/to/fake1.test_bundle').and_return(true)
      allow(Dir).to receive(:exist?).with('path/to/fake2.test_bundle').and_return(true)
      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:exist?).with('path/to/fake1.test_bundle/Info.plist').and_return(true)
      allow(Plist).to receive(:parse_xml).with('path/to/fake1.test_bundle/Info.plist').and_return(info_plist_1)
      allow(File).to receive(:exist?).with('path/to/fake2.test_bundle/Info.plist').and_return(true)
      allow(Plist).to receive(:parse_xml).with('path/to/fake2.test_bundle/Info.plist').and_return(info_plist_2)
      expect(Plist::Emit).to receive(:save_plist).with(info_plist_1, 'path/to/fake1.test_bundle/Info.plist')
      Fastlane::FastFile.new.parse(fastfile).runner.execute(:test)
      expect(info_plist_1['Actions'][0]['EndedTime']).to eq(DateTime.parse('2018-06-25T13:32:11Z'))
      expect(info_plist_1['Actions'][0]['ActionResult']['TestsFailedCount']).to eq(3)
    end

    it 'merges TestSummaries.plist files' do
      fastfile = "lane :test do
        collate_test_result_bundles(
          bundles: ['path/to/fake1.test_bundle', 'path/to/fake2.test_bundle'],
          collated_bundle: 'path/to/report.test_bundle'
        )
      end"
      test_result_bundle_files = {
        '1' => ['TestSummaries.plist'],
        '2' => ['TestSummaries.plist']
      }
      allow(Dir).to receive(:foreach).with(%r{path/to/fake\d\.test_bundle}) do |dirname, &_block|
        %r{path/to/fake(?<bundle_number>\d)\.test_bundle} =~ dirname

        _block.call(test_result_bundle_files[bundle_number].shift)
      end
      allow(Dir).to receive(:exist?).with('path/to/fake1.test_bundle').and_return(true)
      allow(Dir).to receive(:exist?).with('path/to/fake2.test_bundle').and_return(true)
      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:exist?).with('path/to/fake1.test_bundle/TestSummaries.plist').and_return(true)
      allow(Plist).to receive(:parse_xml).with('path/to/fake1.test_bundle/TestSummaries.plist').and_return(test_summaries_plist_1)
      allow(File).to receive(:exist?).with('path/to/fake2.test_bundle/TestSummaries.plist').and_return(true)
      allow(Plist).to receive(:parse_xml).with('path/to/fake2.test_bundle/TestSummaries.plist').and_return(test_summaries_plist_2)
      expect(Plist::Emit).to receive(:save_plist).with(test_summaries_plist_1, 'path/to/fake1.test_bundle/TestSummaries.plist')

      original_tests = test_summaries_plist_1['TestableSummaries'][0]['Tests']
      Fastlane::FastFile.new.parse(fastfile).runner.execute(:test)
      expect(test_summaries_plist_1['TestableSummaries'][0]['PreviousTests']).to eq(original_tests)
      expect(test_summaries_plist_1['TestableSummaries'][0]['Tests']).to eq(test_summaries_plist_2['TestableSummaries'][0]['Tests'])
    end

    it 'merges test target\'s TestSummaries.plist' do
      fastfile = "lane :test do
        collate_test_result_bundles(
          bundles: ['path/to/fake1.test_bundle', 'path/to/fake2.test_bundle'],
          collated_bundle: 'path/to/report.test_bundle'
        )
      end"
      test_result_bundle_files = {
        '1' => ['1_Test'],
        '2' => ['1_Test']
      }
      allow(Dir).to receive(:exist?).with('path/to/fake1.test_bundle').and_return(true)
      allow(Dir).to receive(:exist?).with('path/to/fake2.test_bundle').and_return(true)
      allow(File).to receive(:exist?).and_call_original
      allow(Dir).to receive(:foreach).with(%r{path/to/fake\d\.test_bundle$}) do |dirname, &_block|
        %r{path/to/fake(?<bundle_number>\d)\.test_bundle} =~ dirname
        test_result_bundle_files[bundle_number].each { |child_item| _block.call(child_item) }
      end
      testsummaries_plist_files = {
        '1' => ['action_TestSummaries.plist'],
        '2' => ['action_TestSummaries.plist']
      }
      allow(Dir).to receive(:foreach).with(%r{path/to/fake\d\.test_bundle/\d_Test}) do |dirname, &_block|
        %r{path/to/fake(?<bundle_number>\d)\.test_bundle/.*} =~ dirname
        testsummaries_plist_files[bundle_number].each { |logfile| _block.call(logfile) }
      end
      expect(Fastlane::Actions::CollateTestResultBundlesAction)
        .to receive(:collate_testsummaries_plist)
        .with(
          'path/to/fake1.test_bundle/1_Test/action_TestSummaries.plist',
          'path/to/fake2.test_bundle/1_Test/action_TestSummaries.plist'
        )

      Fastlane::FastFile.new.parse(fastfile).runner.execute(:test)
    end

    it 'merges Attachments directory' do
      fastfile = "lane :test do
        collate_test_result_bundles(
          bundles: ['path/to/fake1.test_bundle', 'path/to/fake2.test_bundle'],
          collated_bundle: 'path/to/report.test_bundle'
        )
      end"
      test_result_bundle_files = {
        '1' => ['Attachments'],
        '2' => ['Attachments']
      }
      allow(Dir).to receive(:exist?).with('path/to/fake1.test_bundle').and_return(true)
      allow(Dir).to receive(:exist?).with('path/to/fake2.test_bundle').and_return(true)
      allow(File).to receive(:exist?).and_call_original
      allow(Dir).to receive(:foreach).with(%r{path/to/fake\d\.test_bundle}) do |dirname, &_block|
        %r{path/to/fake(?<bundle_number>\d)\.test_bundle} =~ dirname

        _block.call(test_result_bundle_files[bundle_number].shift)
      end
      expect(FileUtils).to receive(:cp_r).with('path/to/fake2.test_bundle/Attachments/.', 'path/to/fake1.test_bundle/Attachments')
      Fastlane::FastFile.new.parse(fastfile).runner.execute(:test)
    end

    it 'merges test target\'s Attachments directories' do
      fastfile = "lane :test do
        collate_test_result_bundles(
          bundles: ['path/to/fake1.test_bundle', 'path/to/fake2.test_bundle'],
          collated_bundle: 'path/to/report.test_bundle'
        )
      end"
      test_result_bundle_files = {
        '1' => ['1_Test', '2_Test'],
        '2' => ['1_Test', '2_Test']
      }
      allow(Dir).to receive(:exist?).with('path/to/fake1.test_bundle').and_return(true)
      allow(Dir).to receive(:exist?).with('path/to/fake2.test_bundle').and_return(true)
      allow(File).to receive(:exist?).and_call_original
      allow(Dir).to receive(:foreach).with(%r{path/to/fake\d\.test_bundle$}) do |dirname, &_block|
        %r{path/to/fake(?<bundle_number>\d)\.test_bundle} =~ dirname
        test_result_bundle_files[bundle_number].each { |child_item| _block.call(child_item) }
      end
      test_target_files = {
        '1' => ['Attachments'],
        '2' => ['Attachments']
      }
      allow(Dir).to receive(:foreach).with(%r{path/to/fake\d\.test_bundle/\d_Test}) do |dirname, &_block|
        %r{path/to/fake(?<bundle_number>\d)\.test_bundle/.*} =~ dirname
        _block.call(test_target_files[bundle_number][0])
      end
      expect(FileUtils).to receive(:cp_r).with('path/to/fake2.test_bundle/1_Test/Attachments/.', 'path/to/fake1.test_bundle/1_Test/Attachments').once.ordered
      expect(FileUtils).to receive(:cp_r).with('path/to/fake2.test_bundle/2_Test/Attachments/.', 'path/to/fake1.test_bundle/2_Test/Attachments').once.ordered
      Fastlane::FastFile.new.parse(fastfile).runner.execute(:test)
    end

    it 'merges test target\'s Diagnostics directories' do
      fastfile = "lane :test do
        collate_test_result_bundles(
          bundles: ['path/to/fake1.test_bundle', 'path/to/fake2.test_bundle'],
          collated_bundle: 'path/to/report.test_bundle'
        )
      end"
      test_result_bundle_files = {
        '1' => ['1_Test', '2_Test'],
        '2' => ['1_Test', '2_Test']
      }
      allow(Dir).to receive(:exist?).with('path/to/fake1.test_bundle').and_return(true)
      allow(Dir).to receive(:exist?).with('path/to/fake2.test_bundle').and_return(true)
      allow(File).to receive(:exist?).and_call_original
      allow(Dir).to receive(:foreach).with(%r{path/to/fake\d\.test_bundle$}) do |dirname, &_block|
        %r{path/to/fake(?<bundle_number>\d)\.test_bundle} =~ dirname
        test_result_bundle_files[bundle_number].each { |child_item| _block.call(child_item) }
      end
      session_diagnostics_directories = {
        '1' => ['Diagnostics'],
        '2' => ['Diagnostics']
      }
      allow(Dir).to receive(:foreach).with(%r{path/to/fake\d\.test_bundle/\d_Test}) do |dirname, &_block|
        %r{path/to/fake(?<bundle_number>\d)\.test_bundle/.*} =~ dirname
        _block.call(session_diagnostics_directories[bundle_number][0])
      end
      expect(FileUtils).to receive(:cp_r).with('path/to/fake2.test_bundle/1_Test/Diagnostics/.', 'path/to/fake1.test_bundle/1_Test/Diagnostics').once.ordered
      expect(FileUtils).to receive(:cp_r).with('path/to/fake2.test_bundle/2_Test/Diagnostics/.', 'path/to/fake1.test_bundle/2_Test/Diagnostics').once.ordered
      Fastlane::FastFile.new.parse(fastfile).runner.execute(:test)
    end

    it 'merges test target\'s xcactivitylogs' do
      fastfile = "lane :test do
        collate_test_result_bundles(
          bundles: ['path/to/fake1.test_bundle', 'path/to/fake2.test_bundle'],
          collated_bundle: 'path/to/report.test_bundle'
        )
      end"
      test_result_bundle_files = {
        '1' => ['1_Test'],
        '2' => ['1_Test']
      }
      allow(Dir).to receive(:exist?).with('path/to/fake1.test_bundle').and_return(true)
      allow(Dir).to receive(:exist?).with('path/to/fake2.test_bundle').and_return(true)
      allow(File).to receive(:exist?).and_call_original
      allow(Dir).to receive(:foreach).with(%r{path/to/fake\d\.test_bundle$}) do |dirname, &_block|
        %r{path/to/fake(?<bundle_number>\d)\.test_bundle} =~ dirname
        test_result_bundle_files[bundle_number].each { |child_item| _block.call(child_item) }
      end
      activity_logfiles = {
        '1' => ['action.xcactivitylog', 'build.xcactivitylog'],
        '2' => ['action.xcactivitylog', 'build.xcactivitylog']
      }
      allow(Dir).to receive(:foreach).with(%r{path/to/fake\d\.test_bundle/\d_Test}) do |dirname, &_block|
        %r{path/to/fake(?<bundle_number>\d)\.test_bundle/.*} =~ dirname
        activity_logfiles[bundle_number].each { |logfile| _block.call(logfile) }
      end
      expect(Fastlane::Actions::CollateTestResultBundlesAction)
        .to receive(:concatenate_zipped_activitylogs)
        .with(
          'path/to/fake1.test_bundle/1_Test/action.xcactivitylog',
          'path/to/fake2.test_bundle/1_Test/action.xcactivitylog'
        )

      expect(Fastlane::Actions::CollateTestResultBundlesAction)
        .to receive(:concatenate_zipped_activitylogs)
        .with(
          'path/to/fake1.test_bundle/1_Test/build.xcactivitylog',
          'path/to/fake2.test_bundle/1_Test/build.xcactivitylog'
        )

      Fastlane::FastFile.new.parse(fastfile).runner.execute(:test)
    end

    it 'concatenates zipped files in the expected manner' do
      expect(Fastlane::Action).to receive(:sh).with('gunzip -k -S .xcactivitylog path/to/fake2.test_bundle/1_Test/action.xcactivitylog', print_command: false, print_command_output: false)
      expect(Fastlane::Action).to receive(:sh).with('gunzip -S .xcactivitylog path/to/fake1.test_bundle/1_Test/action.xcactivitylog', print_command: false, print_command_output: false)
      expect(Fastlane::Action).to receive(:sh).with('cat path/to/fake2.test_bundle/1_Test/action > path/to/fake1.test_bundle/1_Test/action', print_command: false, print_command_output: false)
      expect(FileUtils).to receive(:rm).with('path/to/fake2.test_bundle/1_Test/action')
      expect(Fastlane::Action).to receive(:sh).with('gzip -S .xcactivitylog path/to/fake1.test_bundle/1_Test/action', print_command: false, print_command_output: false)

      Fastlane::Actions::CollateTestResultBundlesAction.concatenate_zipped_activitylogs(
        'path/to/fake1.test_bundle/1_Test/action.xcactivitylog',
        'path/to/fake2.test_bundle/1_Test/action.xcactivitylog'
      )
    end
  end
end
