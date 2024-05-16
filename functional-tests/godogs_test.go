package functional_test

import (
	"context"
	"log"
	"os"
	"testing"

	"github.com/cucumber/godog"
	"github.com/cucumber/godog/colors"
	"github.com/spf13/pflag" // godog v0.11.0 and later
	"k8s.io/apimachinery/pkg/apis/meta/v1/unstructured"
	"sigs.k8s.io/e2e-framework/pkg/envconf"
	"sigs.k8s.io/e2e-framework/pkg/envfuncs"
)

var (
	// Variables to be used across files
	parentTenant *unstructured.Unstructured
	childTenant  *unstructured.Unstructured
	tenant       *unstructured.Unstructured

	internalOciRegistry       string
	releaseVersion            string
	releaseRevision           string
	environmentConfigFilePath string
	namespaceName             string
	k8sContext                string
	k8sCfg                    *envconf.Config

	opts = godog.Options{
		Output: colors.Colored(os.Stdout),
		Paths:  []string{"features"},
		Format: "pretty",
	}
)

func init() {
	godog.BindCommandLineFlags("godog.", &opts)
	namespaceName = envconf.RandomName("k8s-e2e-test", 21)
}

func TestMain(m *testing.M) {
	internalOciRegistry = os.Getenv("INTERNAL_OCI_REGISTRY")
	releaseVersion = os.Getenv("RELEASE_VERSION")
	releaseRevision = os.Getenv("RELEASE_REVISION")
	k8sContext = os.Getenv("KUBE_CONTEXT")
	environmentConfigFilePath = os.Getenv("ENVIRONMENT_CONFIG_FILE")

	pflag.Parse()

	k8sCfg = envconf.New().WithKubeContext(k8sContext).WithNamespace(namespaceName)
	log.Printf("Running Tags: %s\n", opts.Tags)
	status := godog.TestSuite{
		Name:                 "godogs",
		TestSuiteInitializer: InitializeTestSuite,
		ScenarioInitializer:  InitializeScenario,
		Options:              &opts,
	}.Run()

	// Optional: Run `testing` package's logic besides godog.
	if st := m.Run(); st > status {
		status = st
	}

	os.Exit(status)
}

func InitializeTestSuite(ctx *godog.TestSuiteContext) {
	// Choosing not to use this has it would create befores/afters that are scenario specific and since we'll run on tags, they might class or be unecessary.
	// Please use https://cucumber.io/docs/gherkin/reference/#background instead

	ctx.BeforeSuite(func() {
		_, _ = envfuncs.CreateNamespace(namespaceName)(context.TODO(), k8sCfg)

	})
	ctx.AfterSuite(func() {
		if tenant != nil {
			if err := k8sCfg.Client().Resources().Delete(context.TODO(), tenant); err != nil {
				log.Println(err)
			}
		}
		if childTenant != nil {
			if err := k8sCfg.Client().Resources().Delete(context.TODO(), childTenant); err != nil {
				log.Println(err)
			}
		}
		if parentTenant != nil {
			if err := k8sCfg.Client().Resources().Delete(context.TODO(), parentTenant); err != nil {
				log.Println(err)
			}
		}
		_, _ = envfuncs.DeleteNamespace(namespaceName)(context.TODO(), k8sCfg)
	})
}

func InitializeScenario(ctx *godog.ScenarioContext) {
	// Add your init test suite here for each new file
}
